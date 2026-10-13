import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { LibraryModule } from '../library/library.module.js';
import { LibraryGateway } from './library.gateway.js';

@Module({
  imports: [AuthModule, LibraryModule],
  providers: [LibraryGateway],
})
export class RealtimeModule {}
