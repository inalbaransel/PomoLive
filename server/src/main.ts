import { NestFactory } from '@nestjs/core';
import { WsAdapter } from '@nestjs/platform-ws';
import { AppModule } from './app.module.js';
import { AppConfig } from './config/app-config.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useWebSocketAdapter(new WsAdapter(app));
  app.enableShutdownHooks();
  await app.listen(app.get(AppConfig).port, '0.0.0.0');
}
await bootstrap();
