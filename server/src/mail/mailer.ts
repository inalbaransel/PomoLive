import { Injectable, Logger } from '@nestjs/common';
import { createTransport, type Transporter } from 'nodemailer';
import { AppConfig } from '../config/app-config.js';
import { ProtocolError } from '../realtime/protocol-error.js';

/**
 * Sends sign-in codes over SMTP. Without `SMTP_URL` the code is written to the log in development,
 * and e-mail sign-in is reported as unavailable in production.
 */
@Injectable()
export class Mailer {
  private readonly logger = new Logger(Mailer.name);
  private readonly transport: Transporter | undefined;

  constructor(private readonly config: AppConfig) {
    this.transport = config.smtpUrl
      ? createTransport(config.smtpUrl)
      : undefined;
    if (!this.transport && config.nodeEnv === 'production') {
      this.logger.warn('SMTP_URL is not set; e-mail sign-in is disabled');
    }
  }

  async sendSignInCode(email: string, code: string): Promise<void> {
    if (!this.transport) {
      if (this.config.nodeEnv === 'production')
        ProtocolError.throw('UNAVAILABLE', 'E-mail sign-in is not configured');
      this.logger.log(`Sign-in code for ${email}: ${code}`);
      return;
    }
    await this.transport.sendMail({
      from: this.config.mailFrom,
      to: email,
      subject: `PomoLive giriş kodun: ${code}`,
      text: `PomoLive'a giriş kodun: ${code}\n\nKod 10 dakika geçerli. Bu isteği sen yapmadıysan bu e-postayı yok sayabilirsin.`,
      html: `<p>PomoLive'a giriş kodun:</p><p style="font:700 32px ui-monospace,monospace;letter-spacing:6px">${code}</p><p>Kod 10 dakika geçerli. Bu isteği sen yapmadıysan bu e-postayı yok sayabilirsin.</p>`,
    });
  }
}
