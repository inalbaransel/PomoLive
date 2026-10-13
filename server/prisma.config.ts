import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    // `prisma generate` runs at image build time without a database, so the URL stays optional here.
    url: process.env['DATABASE_URL'] ?? '',
  },
});
