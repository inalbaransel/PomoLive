import { Controller, Get, Header } from '@nestjs/common';
import { AppConfig } from '../config/app-config.js';
import { privacyPage, supportPage, termsPage } from './legal-pages.js';

/** Public pages for App Store Connect and the app's settings: privacy, terms and support. */
@Controller()
export class LegalController {
  private readonly pages: { privacy: string; terms: string; support: string };

  constructor(config: AppConfig) {
    this.pages = {
      privacy: privacyPage(config.supportEmail),
      terms: termsPage(config.supportEmail),
      support: supportPage(config.supportEmail),
    };
  }

  @Get('privacy')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'public, max-age=3600')
  privacy(): string {
    return this.pages.privacy;
  }

  @Get('terms')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'public, max-age=3600')
  terms(): string {
    return this.pages.terms;
  }

  @Get('support')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'public, max-age=3600')
  support(): string {
    return this.pages.support;
  }
}
