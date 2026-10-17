import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { createPrivateKey, KeyObject, sign } from 'node:crypto';
import { ClientHttp2Session, connect } from 'node:http2';
import { AppConfig, ApnsCredentials } from '../config/app-config.js';

export type PushEnvironment = 'SANDBOX' | 'PRODUCTION';

export interface ApnsNotification {
  payload: object;
  /** Replaces an earlier notification with the same id still on screen. */
  collapseId?: string;
}

/** `gone` means the token will never work again and should be forgotten. */
export type ApnsResult = 'sent' | 'gone' | 'failed';

const HOSTS: Record<PushEnvironment, string> = {
  SANDBOX: 'https://api.sandbox.push.apple.com',
  PRODUCTION: 'https://api.push.apple.com',
};
/** Apple accepts a provider token for an hour and rejects refreshing it more than every 20 minutes. */
const TOKEN_LIFETIME_MS = 50 * 60_000;
const REQUEST_TIMEOUT_MS = 10_000;
const DEAD_TOKEN_REASONS = new Set([
  'BadDeviceToken',
  'DeviceTokenNotForTopic',
  'Unregistered',
]);

/**
 * Apple Push Notification service over HTTP/2 with token (.p8) authentication, without a
 * third-party dependency: one long-lived connection per environment, a cached ES256 JWT.
 */
@Injectable()
export class ApnsClient implements OnModuleDestroy {
  private readonly logger = new Logger(ApnsClient.name);
  private readonly credentials: ApnsCredentials | null;
  private readonly key: KeyObject | null;
  private readonly sessions = new Map<PushEnvironment, ClientHttp2Session>();
  private providerToken: { value: string; issuedAt: number } | null = null;

  constructor(config: AppConfig) {
    this.credentials = config.apns;
    this.key = config.apns ? createPrivateKey(config.apns.privateKey) : null;
    if (!this.credentials)
      this.logger.log('APNs is not configured; push notifications are off');
  }

  get isEnabled(): boolean {
    return this.credentials !== null;
  }

  onModuleDestroy(): void {
    for (const session of this.sessions.values()) session.close();
  }

  async send(
    token: string,
    environment: PushEnvironment,
    notification: ApnsNotification,
  ): Promise<ApnsResult> {
    if (!this.credentials) return 'failed';
    const headers: Record<string, string> = {
      ':method': 'POST',
      ':path': `/3/device/${token}`,
      authorization: `bearer ${this.jwt()}`,
      'apns-topic': this.credentials.bundleId,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      ...(notification.collapseId
        ? { 'apns-collapse-id': notification.collapseId }
        : {}),
    };
    try {
      const { status, body } = await this.request(
        environment,
        headers,
        JSON.stringify(notification.payload),
      );
      if (status === 200) return 'sent';
      const reason = (JSON.parse(body || '{}') as { reason?: string }).reason;
      if (status === 410 || (reason && DEAD_TOKEN_REASONS.has(reason)))
        return 'gone';
      this.logger.warn(`APNs ${status} ${reason ?? ''}`);
      return 'failed';
    } catch (error) {
      this.logger.warn(`APNs request failed: ${(error as Error).message}`);
      return 'failed';
    }
  }

  private request(
    environment: PushEnvironment,
    headers: Record<string, string>,
    body: string,
  ): Promise<{ status: number; body: string }> {
    return new Promise((resolve, reject) => {
      const stream = this.session(environment).request(headers);
      let status = 0;
      let response = '';
      stream.setEncoding('utf8');
      stream.setTimeout(REQUEST_TIMEOUT_MS, () =>
        stream.close(undefined, () => reject(new Error('timeout'))),
      );
      stream.on('response', (head) => (status = Number(head[':status'])));
      stream.on('data', (chunk: string) => (response += chunk));
      stream.on('end', () => resolve({ status, body: response }));
      stream.on('error', reject);
      stream.end(body);
    });
  }

  private session(environment: PushEnvironment): ClientHttp2Session {
    const existing = this.sessions.get(environment);
    if (existing && !existing.closed && !existing.destroyed) return existing;
    const session = connect(HOSTS[environment]);
    const forget = () => {
      if (this.sessions.get(environment) === session)
        this.sessions.delete(environment);
    };
    session.on('error', (error: Error) => {
      this.logger.warn(`APNs connection error: ${error.message}`);
      forget();
    });
    session.on('close', forget);
    session.on('goaway', forget);
    // An idle connection must not keep the process alive on shutdown.
    session.unref();
    this.sessions.set(environment, session);
    return session;
  }

  private jwt(): string {
    const now = Date.now();
    if (
      this.providerToken &&
      now - this.providerToken.issuedAt < TOKEN_LIFETIME_MS
    )
      return this.providerToken.value;
    const { keyId, teamId } = this.credentials!;
    const encode = (part: object) =>
      Buffer.from(JSON.stringify(part)).toString('base64url');
    const input = `${encode({ alg: 'ES256', kid: keyId })}.${encode({ iss: teamId, iat: Math.floor(now / 1000) })}`;
    const signature = sign('sha256', Buffer.from(input), {
      key: this.key!,
      dsaEncoding: 'ieee-p1363',
    }).toString('base64url');
    this.providerToken = { value: `${input}.${signature}`, issuedAt: now };
    return this.providerToken.value;
  }
}
