import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    include: ['**/*.e2e-spec.ts'],
    // Purchases in the tests are signed like Xcode's local StoreKit testing signs them.
    env: { ALLOW_XCODE_TRANSACTIONS: 'true' },
  },
});
