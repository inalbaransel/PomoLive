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
import { AuthService } from '../auth/auth.service.js';
import { LibraryService, ReaderSession } from '../library/library.service.js';
import { ProtocolError } from './protocol-error.js';
import { ProtocolErrorFilter } from './protocol-error.filter.js';
import {
  authCommandSchema,
  ClientEvent,
  heartbeatSchema,
  joinRoomSchema,
  parsePayload,
  refSchema,
  ServerEvent,
  setStatusSchema,
  sitSchema,
  updateProfileSchema,
} from './protocol.js';
import { Frame, RoomEventBus } from './room-event-bus.js';

const AUTH_TIMEOUT_MS = 10_000;
const PING_INTERVAL_MS = 25_000;
const CLOSE_UNAUTHORIZED = 4401;

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
    private readonly library: LibraryService,
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
        .disconnect(connection.session)
        .catch((error: Error) => this.logger.error(error.message));
    }
  }

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
    connection.session = {
      user,
      timeZone: command.timeZone,
      roomId: connection.session?.roomId ?? null,
    };
    return reply(data, {
      user,
      sessionToken: session.token,
      sessionExpiresAt: session.expiresAt,
    });
  }

  @SubscribeMessage(ClientEvent.joinRoom)
  async onJoin(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { code } = parsePayload(joinRoomSchema, data);
    return reply(data, await this.library.join(this.sessionOf(socket), code));
  }

  @SubscribeMessage(ClientEvent.createRoom)
  async onCreate(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    return reply(
      data,
      await this.library.createPrivateRoom(this.sessionOf(socket)),
    );
  }

  @SubscribeMessage(ClientEvent.leaveRoom)
  async onLeave(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    await this.library.leave(this.sessionOf(socket));
    return reply(data, {});
  }

  @SubscribeMessage(ClientEvent.sit)
  async onSit(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { deskId, taskLabel } = parsePayload(sitSchema, data);
    return reply(data, {
      desk: await this.library.sit(this.sessionOf(socket), deskId, taskLabel),
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

  @SubscribeMessage(ClientEvent.setStatus)
  async onStatus(
    @ConnectedSocket() socket: WebSocket,
    @MessageBody() data: Payload,
  ) {
    const { status } = parsePayload(setStatusSchema, data);
    return reply(data, {
      desk: await this.library.setStatus(this.sessionOf(socket), status),
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

  private sessionOf(socket: WebSocket): ReaderSession {
    return (
      this.connections.get(socket)?.session ??
      ProtocolError.throw('UNAUTHORIZED', 'Authenticate first')
    );
  }

  private fanOut(roomId: string, frame: Frame): void {
    const message = JSON.stringify(frame);
    for (const [socket, connection] of this.connections) {
      if (
        connection.session?.roomId === roomId &&
        socket.readyState === WebSocket.OPEN
      )
        socket.send(message);
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
