import { Injectable } from '@nestjs/common';
import { AuthService } from '../auth/auth.service.js';
import { LibraryService } from '../library/library.service.js';
import { RoomsService } from '../rooms/rooms.service.js';
import { UsersRepository } from '../users/users.repository.js';

/** Account deletion, required by the App Store for apps that let people sign up. */
@Injectable()
export class AccountService {
  constructor(
    private readonly auth: AuthService,
    private readonly library: LibraryService,
    private readonly rooms: RoomsService,
    private readonly users: UsersRepository,
  ) {}

  async delete(userId: string, password: string): Promise<void> {
    await this.auth.confirmPassword(userId, password);
    await this.library.standUp(userId);
    for (const roomId of await this.rooms.ownedRoomIds(userId))
      await this.library.closeRoom(roomId);
    await this.users.delete(userId);
  }
}
