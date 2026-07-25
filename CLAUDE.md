# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`checkout-service` — a small Express/TypeScript checkout+orders service used as **Lab B** of a Claude Code bootcamp (Dev + QA tracks). **This is the SOLUTION branch**: every assignment in `docs/ASSIGNMENTS.md` is already implemented, `npm run build` is clean and all tests pass. `SOLUTION.md` (Thai) is the instructor's answer key and explains what differs from the student repo and which teaching points to highlight.

## Commands

```bash
npm install
npm run build            # tsc -> dist/
npm run typecheck        # tsc --noEmit
npm test                 # jest (ts-jest, node env, src/**/__tests__/*.test.ts)
npm run dev              # tsx watch src/index.ts -> http://localhost:3000
npm start                # node dist/index.js (requires build first)

npx jest src/__tests__/inventory.test.ts        # single test file
npx jest -t 'concurrent same-key'               # single test by name
```

There is no linter configured. `dist/` is gitignored but checked out locally — it is stale build output, never edit it.

## Architecture

Layering is strict, one direction: `routes → services → repositories`.

- **`repositories/asyncStore.ts`** is the foundation of the whole lab. It is a `Map` wrapper where *every* operation `await`s a `setTimeout(0)` tick. That artificial latency is deliberate — it forces concurrent callers to interleave so check-then-act races are reproducible. Do not "optimize" the tick away. `productRepo`, `orderRepo`, and `couponRepo` are all thin `createAsyncStore` instances keyed by `sku` / `id` / `code`.
- **Module-level singletons.** The repos and the idempotency store in `orderService.ts` are module-scope singletons with no reset hook. Tests must call `repo.seed([...])` in `beforeEach` to isolate state; `seed` is the only synchronous-clear operation.
- **`lib/locks.ts` — `withLock(key, fn)`** is a per-key async mutex built from a `Map<string, Promise>` chain. It is the single answer to both lab bugs: `inventoryService` locks on `sku:${sku}`, `orderService` locks on `idem:${key}`. The chain tail is stored with `.catch(() => undefined)` so one rejection doesn't poison later waiters on that key. This map is also process-global and never pruned.
- **`lib/money.ts` / `Cents`** — all money is an **integer number of cents**; there are no floats anywhere in pricing. Rounding is half-up via `Math.round`. Tax is `TAX_BPS = 700` (7%) in `pricingService`, charged on `subtotal - discount`, and the discount is clamped to `[0, subtotal]` inside `priceCart` (a second clamp beyond the one in `discountForCoupon`).
- **`lib/clock.ts`** — `Clock` is injected into `discountForCoupon` so coupon-expiry tests are deterministic (`fixedClock(iso)`). Expiry is `expiresAt <= now`, i.e. exactly-at-expiry counts as expired.

### Checkout flow (`services/orderService.ts`)

`checkout()` wraps `doCheckout()` with idempotency; the ordering inside is load-bearing and the main thing to preserve when editing:

1. Without an `Idempotency-Key`, `doCheckout` runs directly.
2. With one, the whole operation runs inside `withLock('idem:' + key)` so concurrent same-key requests serialize rather than double-charge.
3. The key is looked up **before** any work, and recorded **only after** `doCheckout` succeeds — writing it earlier would make a failed attempt permanently unretryable.
4. `doCheckout` reserves stock line by line and, on any failure, `release`s everything already reserved before throwing (rollback). This is the step most easily broken.

### HTTP surface

`createApp()` in `src/app.ts` is async because it seeds products and coupons before returning; `index.ts` and supertest-based tests both await it. Routes: `GET /health`, `GET /products`, `POST /orders/checkout` (body `{ lines, couponCode }`, header `Idempotency-Key`). `middleware/errorHandler.ts` maps every thrown error to HTTP **400** with `{ error: message }` — there is no error taxonomy, so unknown SKU, bad quantity, and insufficient stock all surface identically.

## Conventions

- Repository access is always `await`ed; treat any read-modify-write across an `await` as a race unless it sits inside `withLock`.
- Services are exported as plain functions (`export async function reserve(...)`), not classes. `inventoryService` is imported namespace-style (`import * as inventory`).
- Tests live in `src/__tests__/*.test.ts` and import services directly; concurrency tests use `Promise.all` and assert both the success count and that stock never goes negative.
- If a concurrency test fails, fix the production code — never relax the assertion. That inversion is the explicit failure mode called out in the lab material.
