import { ArgumentsHost, Catch, Logger } from '@nestjs/common';
import { BaseWsExceptionFilter } from '@nestjs/websockets';
import { WebSocket } from 'ws';
import { ProtocolError } from './protocol-error.js';
import { ServerEvent } from './protocol.js';

/** Turns any handler failure into a `reply` with `ok: false`, so the client's pending request resolves. */
@Catch()
export class ProtocolErrorFilter extends BaseWsExceptionFilter {
  private readonly logger = new Logger(ProtocolErrorFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const context = host.switchToWs();
    const socket = context.getClient<WebSocket>();
    const ref = (context.getData<{ ref?: unknown } | undefined>()?.ref as string | undefined) ?? null;

    const error =
      exception instanceof ProtocolError
        ? { code: exception.code, message: exception.message }
        : { code: 'INTERNAL', message: 'Something went wrong' };
    if (!(exception instanceof ProtocolError)) this.logger.error(exception);

    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({ event: ServerEvent.reply, data: { ref, ok: false, error } }));
    }
  }
}
