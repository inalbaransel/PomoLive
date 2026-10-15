import {
  Logger,
  OnModuleDestroy,
  OnModuleInit,
  UseFilters,
} from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
} from '@nestjs/websockets';
import { WebSocket } from 'ws';
import { AccountService } from '../account/account.service.js';
import { AuthService } from '../auth/auth.service.js';
import { BUILT_IN_CATEGORIES } from '../categories/built-in-categories.js';
import { CategoriesRepository } from '../categories/categories.repository.js';
import { LibraryService, ReaderSession } from '../library/library.service.js';
import { RoomsService } from '../rooms/rooms.service.js';
import { StatsService } from '../stats/stats.service.js';
import { ProtocolError } from './protocol-error.js';
import { ProtocolErrorFilter } from './protocol-error.filter.js';
import {
  authCommandSchema,
  changeTimerSchema,
  ClientEvent,
  createCategorySchema,
  createRoomSchema,
  deleteAccountSchema,
  deleteCategorySchema,
  deleteRoomSchema,
  heartbeatSchema,
  historySchema,
  joinRoomSchema,
  parsePayload,
  refSchema,
  ServerEvent,
  sitSchema,
  updateProfileSchema,
} from './protocol.js';
import { Frame, RoomEventBus } from './room-event-bus.js';

const AUTH_TIMEOUT_MS = 10_000;
const PING_INTERVAL_MS = 25_000;
const CLOSE_UNAUTHORIZED = 4401;
const CLOSE_ACCOUNT_DELETED = 4410;

interface Connection {
  session: ReaderSession | null;
  isAlive: boolean;
  authTimer: NodeJS.Timeout | undefined;
}

type Payload = Record<string, unknown> | undefined;

@WebSocketGateway({ path: '/ws', maxPayload: 16 * 1024 })
@UseFilters(ProtocolErrorFilter)
export class LibraryGateway
  implements
    OnGatewayConnection,
    OnGatewayDisconnect,
    OnModuleInit,
    OnModuleDestroy
{
  private readonly logger = new Logger(LibraryGateway.name);
  private readonly connections = new Map<WebSocket, Connection>();
  private pingTimer: NodeJS.Timeout | undefined;

  constructor(
    private readonly auth: AuthService,
    private readonly account: AccountService,
    private readonly library: LibraryService,
    private readonly rooms: RoomsService,
    private readonly categories: CategoriesRepository,
    private readonly stats: StatsService,
    private readonly bus: RoomEventBus,
  ) {}

  onModuleInit(): void {
    this.bus.subscribe((roomId, frame) => this.fanOut(roomId, frame));
    this.pingTimer = setInterval(() => this.pingAll(), PING_INTERVAL_MS);
  }

  onModuleDestroy(): void {
    clearInterval(this.pingTimer);
  }

  handleConnection(socket: WebSocket): void {
    const connection: Connection = {
      session: null,
      isAlive: true,
      authTimer: setTimeout(
        () => socket.close(CLOSE_UNAUTHORIZED, 'Authentication timeout'),
        AUTH_TIMEOUT_MS,
      ),
    };
    socket.on('pong', () => (connection.isAlive = true));
    this.connections.set(socket, connection);
  }

  async handleDisconnect(socket: WebSocket): Promise<void> {
    const connection = this.connections.get(socket);
    this.connections.delete(socket);
    if (!connection) return;
    clearTimeout(connection.authTimer);
    if (connection.session) {
      await this.library
        .stopViewing(connection.session)
        .catch((error: Error) => this.logger.error(error.message));
    }
  }

  // MARK: Account

  @SubscribeMessage(ClientEvent.auth)
  async onAuth(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const connection =
      this.connections.get(socket) ??
      ProtocolError.throw('UNAUTHORIZED', 'Unknown connection');
    const command = parsePayload(authCommandSchema, data);
    const { user, session } = await this.auth.authenticate(command);

    clearTimeout(connection.authTimer);
    connection.session = { user, timeZone: command.timeZone, roomId: null };
    return reply(data, {
      user,
      sessionToken: session.token,
      sessionExpiresAt: session.expiresAt,
    });
  }

  @SubscribeMessage(ClientEvent.updateProfile)
  async onProfile(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const changes = parsePayload(updateProfileSchema, data);
    return reply(data, {
      user: await this.library.updateProfile(this.sessionOf(socket), changes),
    });
  }

  @SubscribeMessage(ClientEvent.deleteAccount)
  async onDeleteAccount(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { password } = parsePayload(deleteAccountSchema, data);
    await this.account.delete(this.sessionOf(socket).user.id, password);
    this.connections.get(socket)!.session = null;
    setTimeout(
      () => socket.close(CLOSE_ACCOUNT_DELETED, 'Account deleted'),
      100,
    );
    return reply(data, {});
  }

  // MARK: Rooms

  @SubscribeMessage(ClientEvent.listRooms)
  async onListRooms(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    return reply(
      data,
      await this.rooms.overview(this.sessionOf(socket).user.id, Date.now()),
    );
  }

  @SubscribeMessage(ClientEvent.discoverRooms)
  async onDiscoverRooms(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    return reply(
      data,
      await this.rooms.discover(this.sessionOf(socket).user.id, Date.now()),
    );
  }

  @SubscribeMessage(ClientEvent.joinRoom)
  async onJoin(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const target = parsePayload(joinRoomSchema, data);
    const session = this.sessionOf(socket);
    const room = await this.rooms.resolve(session.user.id, target, Date.now());
    return reply(data, await this.library.enter(session, room));
  }

  @SubscribeMessage(ClientEvent.createRoom)
  async onCreateRoom(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { name, symbol, color, visibility } = parsePayload(
      createRoomSchema,
      data,
    );
    const session = this.sessionOf(socket);
    const room = await this.rooms.create(
      session.user.id,
      name,
      { symbol, color },
      visibility,
    );
    return reply(data, await this.library.enter(session, room));
  }

  @SubscribeMessage(ClientEvent.deleteRoom)
  async onDeleteRoom(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { roomId } = parsePayload(deleteRoomSchema, data);
    const room = await this.rooms.owned(this.sessionOf(socket).user.id, roomId);
    await this.library.closeRoom(room.id);
    await this.rooms.delete(room.id);
    return reply(data, {});
  }

  @SubscribeMessage(ClientEvent.forgetRoom)
  async onForgetRoom(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { roomId } = parsePayload(deleteRoomSchema, data);
    await this.rooms.forget(this.sessionOf(socket).user.id, roomId);
    return reply(data, {});
  }

  @SubscribeMessage(ClientEvent.leaveRoom)
  async onLeave(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    await this.library.stopViewing(this.sessionOf(socket));
    return reply(data, {});
  }

  // MARK: Desk

  @SubscribeMessage(ClientEvent.sit)
  async onSit(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const request = parsePayload(sitSchema, data);
    return reply(data, {
      desk: await this.library.sit(this.sessionOf(socket), request),
    });
  }

  @SubscribeMessage(ClientEvent.stand)
  async onStand(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    await this.library.stand(this.sessionOf(socket));
    return reply(data, {});
  }

  @SubscribeMessage(ClientEvent.changeTimer)
  async onChangeTimer(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { action } = parsePayload(changeTimerSchema, data);
    return reply(data, {
      desk: await this.library.changeTimer(this.sessionOf(socket), action),
    });
  }

  @SubscribeMessage(ClientEvent.mySeat)
  async onMySeat(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    return reply(data, {
      ...(await this.library.mySeat(this.sessionOf(socket).user.id)),
      serverTime: Date.now(),
    });
  }

  @SubscribeMessage(ClientEvent.heartbeat)
  async onHeartbeat(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { background } = parsePayload(heartbeatSchema, data);
    return reply(
      data,
      await this.library.heartbeat(this.sessionOf(socket), background),
    );
  }

  // MARK: Categories & stats

  @SubscribeMessage(ClientEvent.listCategories)
  async onListCategories(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const custom = await this.categories.listCustom(
      this.sessionOf(socket).user.id,
    );
    return reply(data, { builtIn: BUILT_IN_CATEGORIES, custom });
  }

  @SubscribeMessage(ClientEvent.createCategory)
  async onCreateCategory(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { name, symbol, color } = parsePayload(createCategorySchema, data);
    return reply(data, {
      category: await this.categories.create(
        this.sessionOf(socket).user.id,
        name,
        { symbol, color },
      ),
    });
  }

  @SubscribeMessage(ClientEvent.deleteCategory)
  async onDeleteCategory(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { id } = parsePayload(deleteCategorySchema, data);
    await this.categories.delete(this.sessionOf(socket).user.id, id);
    return reply(data, {});
  }

  @SubscribeMessage(ClientEvent.statsSummary)
  async onStatsSummary(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const session = this.sessionOf(socket);
    return reply(
      data,
      await this.stats.summary(session.user.id, session.timeZone),
    );
  }

  @SubscribeMessage(ClientEvent.history)
  async onHistory(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { before, limit } = parsePayload(historySchema, data);
    return reply(
      data,
      await this.stats.history(this.sessionOf(socket).user.id, before, limit),
    );
  }

  // MARK: Plumbing

  private sessionOf(socket: WebSocket): ReaderSession {
    return (
      this.connections.get(socket)?.session ??
      ProtocolError.throw('UNAUTHORIZED', 'Authenticate first')
    );
  }

  /**
   * Room events go to everyone looking at the room, and desk events also to the desk's owner
   * wherever they are, so a reader browsing other tabs still learns their desk was freed.
   */
  private fanOut(roomId: string, frame: Frame): void {
    const message = JSON.stringify(frame);
    const data = frame.data as { userId?: string; desk?: { userId: string } };
    const deskOwner = data.userId ?? data.desk?.userId;
    for (const [socket, connection] of this.connections) {
      const session = connection.session;
      if (!session || socket.readyState !== WebSocket.OPEN) continue;
      if (session.roomId === roomId || session.user.id === deskOwner)
        socket.send(message);
      if (frame.event === ServerEvent.roomClosed && session.roomId === roomId)
        session.roomId = null;
    }
  }

  /** Detects half-open TCP connections (e.g. a phone that lost signal) that never sent a close frame. */
  private pingAll(): void {
    for (const [socket, connection] of this.connections) {
      if (!connection.isAlive) {
        socket.terminate();
        continue;
      }
      connection.isAlive = false;
      socket.ping();
    }
  }
}

function reply(data: Payload, result: object) {
  const { ref } = parsePayload(refSchema, data);
  return { event: ServerEvent.reply, data: { ref, ok: true, result } };
}
