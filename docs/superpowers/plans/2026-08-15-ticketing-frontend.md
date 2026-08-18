# Ticketing Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the purchase journey against the orders API — a multi-tier ticket picker, an orders list and detail view with downloadable QR tickets, polished checkout states, and a cancellation modal.

**Architecture:** The backend now exposes `Order → Booking → Ticket`. The frontend's job is to let a buyer assemble a cart across tiers, hand it to `POST /events/:id/orders`, follow the Stripe redirect, and then live with the resulting order: view its tickets, download their PDFs, and cancel before the cutoff. Cart state is ephemeral local state inside the picker — it never outlives the page, because the server owns inventory truth. Every server failure carries a typed `code`, and the UI maps those codes to specific messages and specific recovery, rather than a generic banner.

**Tech Stack:** Next.js 15 (App Router), React 19, TypeScript, Tailwind CSS 4, TanStack React Query 5, Axios, framer-motion, lucide-react, date-fns, `qrcode.react` (new). Tests: Jest + React Testing Library.

**Source spec:** `docs/superpowers/specs/2026-08-15-ticketing-qr-cancellation-design.md` §11

**Depends on:** the ticketing backend, merged at `5e307b0`.

## Global Constraints

- **Extend the existing design language; do not invent a new one.** It is defined in `frontend/src/app/globals.css`: uppercase black display type, `#FF0000` accent (`--color-accent`), hard black/white, **no rounded corners**, 2px underline-offset-4 hovers, `::selection` inverted. Utility classes already available: `.heading-display`, `.heading-section`, `.heading-card`, `.text-editorial`, `.text-tight`.
- Match the idiom in `frontend/src/components/EventCard.tsx`: `font-black uppercase tracking-tight`, borders over shadows, `bg-black/5` fills, `text-black/50` for secondary text.
- All components are TypeScript with explicit prop types. No `any`.
- Client components carry `"use client";` as the first line.
- Data fetching goes through TanStack React Query, following the existing `frontend/src/hooks/useEvents.ts` pattern. Do not call Axios directly from a component.
- **Touch targets are at least 44×44px.** Quantity steppers are the main risk — size them accordingly.
- **Never remove focus rings.** `globals.css` sets `:focus-visible { outline: 2px solid #000; outline-offset: 2px; }` — keep it reachable on every interactive element.
- Every async action shows a state: a skeleton or spinner past ~300ms, and a disabled control while a mutation is in flight.
- Money is formatted with `Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' })`. Never hand-concatenate a euro sign.
- Dates are formatted with `date-fns` `format`, in the user's local timezone.
- Run `npm run lint` in `frontend/` before every commit; fix what it reports.
- Tests are Jest + RTL, colocated under `frontend/src/__tests__/`, matching the existing `EventCard.test.tsx`.

---

## File Structure

**New API layer**
- `frontend/src/types/order.ts` — `Order`, `Booking`, `Ticket`, `OrderStatus`, `ApiError`
- `frontend/src/lib/errorMessages.ts` — typed `code → message` map
- `frontend/src/services/orderService.ts` — every `/orders` and `/tickets` call
- `frontend/src/hooks/useOrders.ts` — React Query hooks and mutations

**New components**
- `frontend/src/components/tickets/TierRow.tsx` — one tier: name, price, stepper, remaining
- `frontend/src/components/tickets/TicketPicker.tsx` — cart reducer, subtotal, submit
- `frontend/src/components/tickets/TicketCard.tsx` — one ticket: QR, code, download
- `frontend/src/components/orders/OrderStatusBadge.tsx` — status pill
- `frontend/src/components/orders/OrderSummaryCard.tsx` — one row in the orders list
- `frontend/src/components/orders/CancelOrderModal.tsx` — refund amount, cutoff, reason, confirm

**New pages**
- `frontend/src/app/profile/orders/page.tsx`
- `frontend/src/app/profile/orders/[id]/page.tsx`

**Modified**
- `frontend/src/app/events/[id]/EventDetailClient.tsx` — old single-tier flow replaced by `TicketPicker`
- `frontend/src/app/checkout/success/page.tsx` — polls until paid
- `frontend/src/app/checkout/cancel/page.tsx` — explains the hold, offers resume
- `frontend/src/app/profile/bookings/page.tsx` — becomes a redirect
- `frontend/src/services/bookingService.ts` — dead methods removed

Each component owns one responsibility and is testable without a router or a live API.

---

### Task 1: Types, error map, and the order service

**Files:**
- Create: `frontend/src/types/order.ts`
- Create: `frontend/src/lib/errorMessages.ts`
- Create: `frontend/src/services/orderService.ts`
- Test: `frontend/src/__tests__/lib/errorMessages.test.ts`

**Interfaces:**
- Consumes: the existing Axios instance at `frontend/src/lib/api.ts`, which already attaches `Authorization: Bearer <token>` from `localStorage.authToken`
- Produces: `orderService.create/list/get/checkout/cancel`, `ticketService.downloadUrl`, the `Order`/`Ticket` types, and `messageForCode(code, fallback)`

- [ ] **Step 1: Write the types**

Create `frontend/src/types/order.ts`:

```ts
export type OrderStatus = 'pending' | 'paid' | 'expired' | 'cancelled' | 'refunded';
export type PaymentStatus = 'unpaid' | 'paid' | 'refunded' | 'failed';
export type TicketStatus = 'issued' | 'checked_in' | 'cancelled';

export interface Ticket {
  id: number;
  code: string;
  status: TicketStatus;
  checked_in_at: string | null;
  ticket_type_name: string;
}

export interface OrderBooking {
  id: number;
  quantity: number;
  total_price: string;
  status: string;
  created_at: string;
  ticket_type: { id: number; name: string; price: string };
  tickets: Ticket[];
}

export interface Order {
  id: number;
  reference: string;
  status: OrderStatus;
  payment_status: PaymentStatus;
  total_amount: string;
  currency: string;
  expires_at: string;
  paid_at: string | null;
  cancelled_at: string | null;
  refunded_at: string | null;
  cancellable: boolean;
  ticket_count: number;
  event: { id: number; name: string; date: string; location: string };
  bookings: OrderBooking[];
}

export interface CartItem {
  ticket_type_id: number;
  quantity: number;
}

/** Every backend failure carries a machine-readable code alongside its message. */
export interface ApiError {
  error: string;
  code: string;
}
```

- [ ] **Step 2: Write the failing test for the error map**

Create `frontend/src/__tests__/lib/errorMessages.test.ts`:

```ts
import { messageForCode } from '@/lib/errorMessages';

describe('messageForCode', () => {
  it('returns a written message for a known code', () => {
    expect(messageForCode('sold_out', 'fallback')).toMatch(/no longer available/i);
  });

  it('returns the cap message for cap_exceeded', () => {
    expect(messageForCode('cap_exceeded', 'fallback')).toMatch(/maximum/i);
  });

  it('falls back to the server message for an unknown code', () => {
    expect(messageForCode('something_new', 'the server said this')).toBe('the server said this');
  });

  it('falls back when no code is given at all', () => {
    expect(messageForCode(undefined, 'the server said this')).toBe('the server said this');
  });

  it('never returns an empty string', () => {
    expect(messageForCode(undefined, '')).toBeTruthy();
  });
});
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd frontend && npx jest src/__tests__/lib/errorMessages.test.ts`
Expected: FAIL — cannot resolve `@/lib/errorMessages`

- [ ] **Step 4: Write the error map**

Create `frontend/src/lib/errorMessages.ts`:

```ts
/**
 * The API answers every failure with a typed code. Mapping them here keeps
 * user-facing copy out of the backend, where it would be written for
 * developers rather than for buyers.
 */
const MESSAGES: Record<string, string> = {
  invalid_items: 'Choose at least one ticket before continuing.',
  sold_out: 'Some of those tickets are no longer available.',
  cap_exceeded: 'That is more than the maximum number of tickets per order for this event.',
  event_past: 'This event has already started.',
  not_payable: 'This order is no longer awaiting payment.',
  payment_in_progress: 'Your payment is still being confirmed. Refresh in a moment.',
  amount_mismatch: 'The price of this order changed. Please start a new order.',
  stripe_error: 'The payment provider could not process that. Please try again.',
  not_completable: 'This order can no longer be paid for.',
  not_cancellable: 'Only paid orders can be cancelled.',
  past_cutoff: 'The cancellation window for this event has closed.',
  already_attended: 'A ticket on this order has already been used at the door.',
  refund_failed: 'We could not process the refund. Please contact support.',
};

const LAST_RESORT = 'Something went wrong. Please try again.';

export function messageForCode(code: string | undefined, serverMessage: string): string {
  if (code && MESSAGES[code]) return MESSAGES[code];
  return serverMessage || LAST_RESORT;
}

export { MESSAGES as ERROR_MESSAGES };
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd frontend && npx jest src/__tests__/lib/errorMessages.test.ts`
Expected: PASS — 5 passed

- [ ] **Step 6: Write the order service**

Create `frontend/src/services/orderService.ts`:

```ts
import api from '@/lib/api';
import { messageForCode } from '@/lib/errorMessages';
import type { CartItem, Order } from '@/types/order';

interface Failure {
  message: string;
  code: string | undefined;
}

/** Normalises an Axios error into the typed shape the UI branches on. */
function toFailure(error: unknown): Failure {
  const err = error as { response?: { data?: { error?: string; code?: string } }; message?: string };
  const code = err.response?.data?.code;
  const serverMessage = err.response?.data?.error || err.message || '';
  return { message: messageForCode(code, serverMessage), code };
}

export class OrderError extends Error {
  code: string | undefined;

  constructor(failure: Failure) {
    super(failure.message);
    this.name = 'OrderError';
    this.code = failure.code;
  }
}

export const orderService = {
  async create(eventId: number, items: CartItem[]): Promise<Order> {
    try {
      const { data } = await api.post(`/events/${eventId}/orders`, { items });
      return data as Order;
    } catch (error) {
      throw new OrderError(toFailure(error));
    }
  },

  async list(page = 1): Promise<{ orders: Order[]; meta: { page: number; pages: number; count: number } }> {
    const { data } = await api.get('/orders', { params: { page } });
    return data;
  },

  async get(id: number): Promise<Order> {
    const { data } = await api.get(`/orders/${id}`);
    return data as Order;
  },

  async checkout(id: number): Promise<{ checkout_url: string; session_id: string }> {
    try {
      const { data } = await api.post(`/orders/${id}/checkout`);
      return data;
    } catch (error) {
      throw new OrderError(toFailure(error));
    }
  },

  async cancel(id: number, reason: string): Promise<Order> {
    try {
      const { data } = await api.delete(`/orders/${id}`, { data: { reason } });
      return data as Order;
    } catch (error) {
      throw new OrderError(toFailure(error));
    }
  },
};

export const ticketService = {
  /** The PDF endpoint needs the bearer token, so fetch it as a blob rather than linking. */
  async download(code: string): Promise<Blob> {
    const { data } = await api.get(`/tickets/${code}/download`, { responseType: 'blob' });
    return data as Blob;
  },
};
```

- [ ] **Step 7: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/src/types/order.ts frontend/src/lib/errorMessages.ts frontend/src/services/orderService.ts frontend/src/__tests__/lib/errorMessages.test.ts
git commit -m "feat(frontend): add order types, typed error map, and order service"
```

---

### Task 2: React Query hooks for orders

**Files:**
- Create: `frontend/src/hooks/useOrders.ts`
- Test: `frontend/src/__tests__/hooks/useOrders.test.tsx`

**Interfaces:**
- Consumes: `orderService` from Task 1
- Produces: `useOrders()`, `useOrder(id)`, `useCreateOrder()`, `useCheckout()`, `useCancelOrder()`

- [ ] **Step 1: Read the existing hook convention**

Run: `cat frontend/src/hooks/useEvents.ts`
Match its query-key shape and options style in what follows.

- [ ] **Step 2: Write the hooks**

Create `frontend/src/hooks/useOrders.ts`:

```ts
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { orderService } from '@/services/orderService';
import type { CartItem } from '@/types/order';

export const orderKeys = {
  all: ['orders'] as const,
  list: (page: number) => ['orders', 'list', page] as const,
  detail: (id: number) => ['orders', 'detail', id] as const,
};

export function useOrders(page = 1) {
  return useQuery({
    queryKey: orderKeys.list(page),
    queryFn: () => orderService.list(page),
  });
}

/**
 * `pollUntilPaid` is used by the checkout success page: Stripe redirects the
 * buyer back before the webhook has necessarily landed, so the page refetches
 * until the order flips to paid rather than showing a premature failure.
 */
export function useOrder(id: number, pollUntilPaid = false) {
  return useQuery({
    queryKey: orderKeys.detail(id),
    queryFn: () => orderService.get(id),
    enabled: Number.isFinite(id) && id > 0,
    refetchInterval: (query) => {
      if (!pollUntilPaid) return false;
      return query.state.data?.status === 'paid' ? false : 2000;
    },
  });
}

export function useCreateOrder() {
  return useMutation({
    mutationFn: ({ eventId, items }: { eventId: number; items: CartItem[] }) =>
      orderService.create(eventId, items),
  });
}

export function useCheckout() {
  return useMutation({
    mutationFn: (orderId: number) => orderService.checkout(orderId),
  });
}

export function useCancelOrder() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, reason }: { id: number; reason: string }) => orderService.cancel(id, reason),
    onSuccess: (order) => {
      queryClient.setQueryData(orderKeys.detail(order.id), order);
      queryClient.invalidateQueries({ queryKey: orderKeys.all });
    },
  });
}
```

- [ ] **Step 3: Write the test**

Create `frontend/src/__tests__/hooks/useOrders.test.tsx`:

```tsx
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { useOrder } from '@/hooks/useOrders';
import { orderService } from '@/services/orderService';

jest.mock('@/services/orderService');

const mockedGet = orderService.get as jest.MockedFunction<typeof orderService.get>;

function wrapper({ children }: { children: ReactNode }) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}

describe('useOrder', () => {
  beforeEach(() => jest.clearAllMocks());

  it('fetches the order', async () => {
    mockedGet.mockResolvedValue({ id: 7, status: 'paid' } as never);

    const { result } = renderHook(() => useOrder(7), { wrapper });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(mockedGet).toHaveBeenCalledWith(7);
  });

  it('does not fetch for an invalid id', () => {
    renderHook(() => useOrder(NaN), { wrapper });
    expect(mockedGet).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 4: Run the test**

Run: `cd frontend && npx jest src/__tests__/hooks/useOrders.test.tsx`
Expected: PASS — 2 passed

- [ ] **Step 5: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/src/hooks/useOrders.ts frontend/src/__tests__/hooks/useOrders.test.tsx
git commit -m "feat(frontend): add React Query hooks for orders"
```

---

### Task 3: The tier row

**Files:**
- Create: `frontend/src/components/tickets/TierRow.tsx`
- Test: `frontend/src/__tests__/components/TierRow.test.tsx`

**Interfaces:**
- Consumes: the `TicketType` type already in `frontend/src/types/index.ts`
- Produces: `<TierRow tier quantity onChange max disabled />` where `max` is the most this tier may go to right now (the lesser of remaining stock and remaining room under the order cap)

This is the smallest unit of the picker and is deliberately dumb: it renders one tier and reports a requested quantity. All arithmetic about caps and totals lives in the parent.

- [ ] **Step 1: Write the failing test**

Create `frontend/src/__tests__/components/TierRow.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import TierRow from '@/components/tickets/TierRow';

const tier = { id: 1, name: 'General Admission', price: '29.99', quantity: 100, available_quantity: 12 };

describe('TierRow', () => {
  it('shows the tier name and a formatted price', () => {
    render(<TierRow tier={tier} quantity={0} max={10} onChange={jest.fn()} />);

    expect(screen.getByText('General Admission')).toBeInTheDocument();
    expect(screen.getByText(/29,99/)).toBeInTheDocument();
  });

  it('increments and decrements', async () => {
    const onChange = jest.fn();
    const user = userEvent.setup();
    render(<TierRow tier={tier} quantity={2} max={10} onChange={onChange} />);

    await user.click(screen.getByRole('button', { name: /add one general admission/i }));
    expect(onChange).toHaveBeenCalledWith(3);

    await user.click(screen.getByRole('button', { name: /remove one general admission/i }));
    expect(onChange).toHaveBeenCalledWith(1);
  });

  it('cannot go below zero', () => {
    render(<TierRow tier={tier} quantity={0} max={10} onChange={jest.fn()} />);
    expect(screen.getByRole('button', { name: /remove one/i })).toBeDisabled();
  });

  it('cannot exceed max, and says why', () => {
    render(<TierRow tier={tier} quantity={4} max={4} onChange={jest.fn()} />);

    expect(screen.getByRole('button', { name: /add one/i })).toBeDisabled();
    expect(screen.getByText(/maximum for this order/i)).toBeInTheDocument();
  });

  it('renders sold out and disables both controls when nothing remains', () => {
    render(<TierRow tier={{ ...tier, available_quantity: 0 }} quantity={0} max={0} onChange={jest.fn()} />);

    expect(screen.getByText(/sold out/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /add one/i })).toBeDisabled();
  });

  it('warns when stock is low', () => {
    render(<TierRow tier={{ ...tier, available_quantity: 3 }} quantity={0} max={3} onChange={jest.fn()} />);
    expect(screen.getByText(/only 3 left/i)).toBeInTheDocument();
  });

  it('does not warn when stock is plentiful', () => {
    render(<TierRow tier={{ ...tier, available_quantity: 40 }} quantity={0} max={10} onChange={jest.fn()} />);
    expect(screen.queryByText(/only \d+ left/i)).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx jest src/__tests__/components/TierRow.test.tsx`
Expected: FAIL — cannot resolve `@/components/tickets/TierRow`

- [ ] **Step 3: Write the component**

Create `frontend/src/components/tickets/TierRow.tsx`:

```tsx
"use client";

import { Minus, Plus } from 'lucide-react';
import clsx from 'clsx';

export interface TierRowTier {
  id: number;
  name: string;
  price: string;
  quantity: number;
  available_quantity: number;
  description?: string | null;
}

interface TierRowProps {
  tier: TierRowTier;
  quantity: number;
  /** The most this tier may reach right now: min(remaining stock, room under the order cap). */
  max: number;
  onChange: (quantity: number) => void;
  disabled?: boolean;
}

const LOW_STOCK_THRESHOLD = 10;

const money = new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' });

export default function TierRow({ tier, quantity, max, onChange, disabled = false }: TierRowProps) {
  const soldOut = tier.available_quantity <= 0;
  const atMax = quantity >= max;
  const lowStock = !soldOut && tier.available_quantity <= LOW_STOCK_THRESHOLD;
  // At the ceiling with stock to spare means the order cap is the binding limit,
  // not inventory — say so rather than leaving a dead button.
  const cappedByOrder = atMax && !soldOut && max < tier.available_quantity;

  const step = (delta: number) => onChange(Math.min(max, Math.max(0, quantity + delta)));

  return (
    <div
      className={clsx(
        'flex items-center justify-between gap-4 border-b-2 border-black py-5',
        soldOut && 'opacity-50'
      )}
    >
      <div className="min-w-0 flex-1">
        <h3 className="heading-card uppercase">{tier.name}</h3>
        {tier.description ? (
          <p className="mt-1 text-sm text-black/50">{tier.description}</p>
        ) : null}

        <p className="mt-2 font-black tabular-nums">{money.format(Number(tier.price))}</p>

        {soldOut ? (
          <p className="mt-1 text-xs font-bold uppercase tracking-wider text-black/50">Sold out</p>
        ) : null}
        {lowStock && !soldOut ? (
          <p className="mt-1 text-xs font-bold uppercase tracking-wider text-[--color-accent]">
            Only {tier.available_quantity} left
          </p>
        ) : null}
        {cappedByOrder ? (
          <p className="mt-1 text-xs font-bold uppercase tracking-wider text-black/50">
            Maximum for this order
          </p>
        ) : null}
      </div>

      <div className="flex shrink-0 items-center gap-1">
        <button
          type="button"
          onClick={() => step(-1)}
          disabled={disabled || quantity <= 0}
          aria-label={`Remove one ${tier.name}`}
          className="flex h-11 w-11 items-center justify-center border-2 border-black transition-colors hover:bg-black hover:text-white disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-transparent disabled:hover:text-black"
        >
          <Minus className="h-4 w-4" aria-hidden="true" />
        </button>

        <span
          className="w-12 text-center text-lg font-black tabular-nums"
          aria-live="polite"
          aria-label={`${quantity} ${tier.name} selected`}
        >
          {quantity}
        </span>

        <button
          type="button"
          onClick={() => step(1)}
          disabled={disabled || soldOut || atMax}
          aria-label={`Add one ${tier.name}`}
          className="flex h-11 w-11 items-center justify-center border-2 border-black transition-colors hover:bg-black hover:text-white disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-transparent disabled:hover:text-black"
        >
          <Plus className="h-4 w-4" aria-hidden="true" />
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && npx jest src/__tests__/components/TierRow.test.tsx`
Expected: PASS — 7 passed

- [ ] **Step 5: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/src/components/tickets/TierRow.tsx frontend/src/__tests__/components/TierRow.test.tsx
git commit -m "feat(frontend): add tier row with quantity stepper and stock states"
```

---

### Task 4: The ticket picker

**Files:**
- Create: `frontend/src/components/tickets/TicketPicker.tsx`
- Test: `frontend/src/__tests__/components/TicketPicker.test.tsx`

**Interfaces:**
- Consumes: `TierRow` from Task 3, `useCreateOrder`/`useCheckout` from Task 2, `OrderError` from Task 1
- Produces: `<TicketPicker eventId tiers maxPerOrder onRequireAuth />`

The picker owns the cart. On submit it creates the order, then either redirects to Stripe (paid) or forwards to the order page (free, since a zero-total order comes back already `paid`).

- [ ] **Step 1: Write the failing test**

Create `frontend/src/__tests__/components/TicketPicker.test.tsx`:

```tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import TicketPicker from '@/components/tickets/TicketPicker';
import { orderService, OrderError } from '@/services/orderService';

jest.mock('@/services/orderService', () => {
  const actual = jest.requireActual('@/services/orderService');
  return { ...actual, orderService: { create: jest.fn(), checkout: jest.fn() } };
});

const mockedCreate = orderService.create as jest.MockedFunction<typeof orderService.create>;
const mockedCheckout = orderService.checkout as jest.MockedFunction<typeof orderService.checkout>;

const tiers = [
  { id: 1, name: 'General Admission', price: '10.00', quantity: 100, available_quantity: 50 },
  { id: 2, name: 'VIP', price: '25.00', quantity: 20, available_quantity: 2 },
];

function renderPicker(props: Partial<React.ComponentProps<typeof TicketPicker>> = {}) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  const wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={client}>{children}</QueryClientProvider>
  );

  return render(
    <TicketPicker eventId={9} tiers={tiers} maxPerOrder={4} isAuthenticated onRequireAuth={jest.fn()} {...props} />,
    { wrapper }
  );
}

describe('TicketPicker', () => {
  beforeEach(() => jest.clearAllMocks());

  it('starts with an empty cart and a disabled CTA', () => {
    renderPicker();
    expect(screen.getByRole('button', { name: /get tickets/i })).toBeDisabled();
  });

  it('totals across tiers', async () => {
    const user = userEvent.setup();
    renderPicker();

    await user.click(screen.getByRole('button', { name: /add one general admission/i }));
    await user.click(screen.getByRole('button', { name: /add one vip/i }));

    expect(screen.getByTestId('cart-total')).toHaveTextContent('35,00');
  });

  it('stops the whole cart at the per-order cap', async () => {
    const user = userEvent.setup();
    renderPicker({ maxPerOrder: 2 });

    await user.click(screen.getByRole('button', { name: /add one general admission/i }));
    await user.click(screen.getByRole('button', { name: /add one general admission/i }));

    expect(screen.getByRole('button', { name: /add one vip/i })).toBeDisabled();
    expect(screen.getByText(/2 of 2 tickets/i)).toBeInTheDocument();
  });

  it('never lets a tier exceed its own remaining stock', async () => {
    const user = userEvent.setup();
    renderPicker({ maxPerOrder: 10 });

    await user.click(screen.getByRole('button', { name: /add one vip/i }));
    await user.click(screen.getByRole('button', { name: /add one vip/i }));

    expect(screen.getByRole('button', { name: /add one vip/i })).toBeDisabled();
  });

  it('sends only the tiers actually chosen', async () => {
    mockedCreate.mockResolvedValue({ id: 3, status: 'pending' } as never);
    mockedCheckout.mockResolvedValue({ checkout_url: 'https://stripe.test/x', session_id: 'cs_1' });

    const user = userEvent.setup();
    renderPicker();

    await user.click(screen.getByRole('button', { name: /add one vip/i }));
    await user.click(screen.getByRole('button', { name: /get tickets/i }));

    await waitFor(() =>
      expect(mockedCreate).toHaveBeenCalledWith(9, [{ ticket_type_id: 2, quantity: 1 }])
    );
  });

  it('surfaces a typed server error', async () => {
    mockedCreate.mockRejectedValue(new OrderError({ message: 'Only 1 VIP ticket(s) remain', code: 'sold_out' }));

    const user = userEvent.setup();
    renderPicker();

    await user.click(screen.getByRole('button', { name: /add one vip/i }));
    await user.click(screen.getByRole('button', { name: /get tickets/i }));

    expect(await screen.findByRole('alert')).toHaveTextContent(/no longer available/i);
  });

  it('asks an anonymous visitor to sign in instead of creating an order', async () => {
    const onRequireAuth = jest.fn();
    const user = userEvent.setup();
    renderPicker({ isAuthenticated: false, onRequireAuth });

    await user.click(screen.getByRole('button', { name: /add one vip/i }));
    await user.click(screen.getByRole('button', { name: /get tickets/i }));

    expect(onRequireAuth).toHaveBeenCalled();
    expect(mockedCreate).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx jest src/__tests__/components/TicketPicker.test.tsx`
Expected: FAIL — cannot resolve `@/components/tickets/TicketPicker`

- [ ] **Step 3: Write the component**

Create `frontend/src/components/tickets/TicketPicker.tsx`:

```tsx
"use client";

import { useMemo, useReducer, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Loader2 } from 'lucide-react';
import TierRow, { type TierRowTier } from './TierRow';
import { useCheckout, useCreateOrder } from '@/hooks/useOrders';
import { OrderError } from '@/services/orderService';

interface TicketPickerProps {
  eventId: number;
  tiers: TierRowTier[];
  /** null means the event places no cap on tickets per order. */
  maxPerOrder: number | null;
  isAuthenticated: boolean;
  onRequireAuth: () => void;
}

type CartState = Record<number, number>;
type CartAction = { type: 'set'; tierId: number; quantity: number };

function cartReducer(state: CartState, action: CartAction): CartState {
  if (action.quantity <= 0) {
    const { [action.tierId]: _removed, ...rest } = state;
    return rest;
  }
  return { ...state, [action.tierId]: action.quantity };
}

const money = new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' });

export default function TicketPicker({
  eventId,
  tiers,
  maxPerOrder,
  isAuthenticated,
  onRequireAuth,
}: TicketPickerProps) {
  const router = useRouter();
  const [cart, dispatch] = useReducer(cartReducer, {} as CartState);
  const [error, setError] = useState<string | null>(null);

  const createOrder = useCreateOrder();
  const checkout = useCheckout();
  const submitting = createOrder.isPending || checkout.isPending;

  const totalQuantity = useMemo(
    () => Object.values(cart).reduce((sum, n) => sum + n, 0),
    [cart]
  );

  const total = useMemo(
    () =>
      tiers.reduce((sum, tier) => sum + Number(tier.price) * (cart[tier.id] ?? 0), 0),
    [cart, tiers]
  );

  const items = useMemo(
    () =>
      Object.entries(cart).map(([ticketTypeId, quantity]) => ({
        ticket_type_id: Number(ticketTypeId),
        quantity,
      })),
    [cart]
  );

  /** Room left under the order cap, once every other tier's choice is counted. */
  const maxFor = (tier: TierRowTier) => {
    const chosen = cart[tier.id] ?? 0;
    const stockCeiling = tier.available_quantity;
    if (maxPerOrder === null) return stockCeiling;

    const roomInOrder = maxPerOrder - (totalQuantity - chosen);
    return Math.max(0, Math.min(stockCeiling, roomInOrder));
  };

  const handleSubmit = async () => {
    setError(null);

    if (!isAuthenticated) {
      onRequireAuth();
      return;
    }

    try {
      const order = await createOrder.mutateAsync({ eventId, items });

      // A zero-total order comes back already paid and never touches Stripe.
      if (order.status === 'paid') {
        router.push(`/profile/orders/${order.id}`);
        return;
      }

      const session = await checkout.mutateAsync(order.id);
      window.location.href = session.checkout_url;
    } catch (err) {
      setError(err instanceof OrderError ? err.message : 'Something went wrong. Please try again.');
    }
  };

  return (
    <section aria-labelledby="tickets-heading" className="border-2 border-black p-6">
      <h2 id="tickets-heading" className="heading-section mb-2">
        Tickets
      </h2>

      {maxPerOrder !== null ? (
        <p className="mb-4 text-xs font-bold uppercase tracking-wider text-black/50">
          {totalQuantity} of {maxPerOrder} tickets
        </p>
      ) : null}

      <div>
        {tiers.map((tier) => (
          <TierRow
            key={tier.id}
            tier={tier}
            quantity={cart[tier.id] ?? 0}
            max={maxFor(tier)}
            disabled={submitting}
            onChange={(quantity) => dispatch({ type: 'set', tierId: tier.id, quantity })}
          />
        ))}
      </div>

      <div className="mt-6 flex items-center justify-between">
        <span className="text-xs font-bold uppercase tracking-wider text-black/50">Total</span>
        <span data-testid="cart-total" className="text-2xl font-black tabular-nums">
          {money.format(total)}
        </span>
      </div>

      {error ? (
        <p role="alert" className="mt-4 border-2 border-[--color-accent] p-3 text-sm font-bold">
          {error}
        </p>
      ) : null}

      <button
        type="button"
        onClick={handleSubmit}
        disabled={totalQuantity === 0 || submitting}
        className="mt-6 flex w-full items-center justify-center gap-2 bg-black px-6 py-4 text-sm font-black uppercase tracking-wider text-white transition-colors hover:bg-[--color-accent] disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-black"
      >
        {submitting ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />
            Working
          </>
        ) : (
          'Get tickets'
        )}
      </button>
    </section>
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && npx jest src/__tests__/components/TicketPicker.test.tsx`
Expected: PASS — 7 passed

- [ ] **Step 5: Add the sticky mobile summary bar**

The spec calls for a sticky summary on mobile: on a phone the tier list pushes the CTA below the fold, so a buyer who has chosen tickets cannot see what they owe or how to proceed.

Add this test to `frontend/src/__tests__/components/TicketPicker.test.tsx`:

```tsx
  it('surfaces a sticky summary once something is in the cart', async () => {
    const user = userEvent.setup();
    renderPicker();

    expect(screen.queryByTestId('sticky-summary')).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /add one general admission/i }));

    const sticky = screen.getByTestId('sticky-summary');
    expect(sticky).toHaveTextContent('10,00');
    expect(sticky).toHaveTextContent(/1 ticket/i);
  });
```

Run it and confirm it fails, then in `TicketPicker.tsx` add this immediately before the closing `</section>`:

```tsx
      {totalQuantity > 0 ? (
        <div
          data-testid="sticky-summary"
          className="fixed inset-x-0 bottom-0 z-40 flex items-center justify-between gap-4 border-t-2 border-black bg-white px-6 py-4 sm:hidden"
        >
          <div>
            <p className="text-xs font-bold uppercase tracking-wider text-black/50">
              {totalQuantity} {totalQuantity === 1 ? 'ticket' : 'tickets'}
            </p>
            <p className="text-lg font-black tabular-nums">{money.format(total)}</p>
          </div>

          <button
            type="button"
            onClick={handleSubmit}
            disabled={submitting}
            className="min-h-11 bg-black px-6 py-3 text-xs font-black uppercase tracking-wider text-white disabled:opacity-30"
          >
            {submitting ? 'Working' : 'Get tickets'}
          </button>
        </div>
      ) : null}
```

The bar is `sm:hidden`, so it never doubles up with the inline CTA on wider screens. Because it is `fixed`, add `pb-28 sm:pb-0` to the page container in Task 5 so the last tier is not hidden behind it.

Run the file again and confirm all 8 tests pass.

- [ ] **Step 6: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/src/components/tickets/TicketPicker.tsx frontend/src/__tests__/components/TicketPicker.test.tsx
git commit -m "feat(frontend): add multi-tier ticket picker with cap enforcement"
```

---

### Task 5: Wire the picker into the event page

**Files:**
- Modify: `frontend/src/app/events/[id]/EventDetailClient.tsx`

**Interfaces:**
- Consumes: `TicketPicker` from Task 4
- Produces: nothing new

The page currently holds a single-tier picker with its own `ticketTypeId`/`quantity` state and a `handleBook` that calls the retired booking endpoints. All of it is replaced.

- [ ] **Step 1: Read the file end to end before editing**

Run: `cat frontend/src/app/events/[id]/EventDetailClient.tsx`

Note every piece of state and every handler that exists only to serve the old booking flow. You are removing: `ticketTypeId`, `quantity`, `submitting`, `submitError`, the `useEffect` that pre-selects the first tier, the `totalPrice` memo, and `handleBook`. Keep everything that renders the event itself — hero, image, description, date, venue.

- [ ] **Step 2: Remove the old flow and mount the picker**

Delete the `bookingService` import and every piece of state listed above. Add:

```tsx
import TicketPicker from '@/components/tickets/TicketPicker';
import { authService } from '@/services/authService';
```

Replace the entire old booking panel in the JSX with:

```tsx
{event.ticket_types && event.ticket_types.length > 0 ? (
  <TicketPicker
    eventId={event.id}
    tiers={event.ticket_types}
    maxPerOrder={event.max_tickets_per_order ?? null}
    isAuthenticated={authService.isAuthenticated()}
    onRequireAuth={() => router.push(`/login?next=/events/${event.id}`)}
  />
) : (
  <section className="border-2 border-black p-6">
    <h2 className="heading-section mb-2">Tickets</h2>
    <p className="text-sm text-black/50">
      Tickets for this event are not on sale yet.
    </p>
  </section>
)}
```

Add `const router = useRouter();` if it is not already present, importing `useRouter` from `next/navigation`.

- [ ] **Step 3: Extend the Event type**

The picker reads `max_tickets_per_order`, which the backend now serializes. In `frontend/src/types/index.ts`, add to the `Event` interface:

```ts
  max_tickets_per_order?: number | null;
  cancel_cutoff_hours?: number | null;
```

And confirm `TicketType` carries `available_quantity`; if it does not, add:

```ts
  available_quantity: number;
```

- [ ] **Step 4: Verify the page builds and renders**

Run: `cd frontend && npx tsc --noEmit`
Expected: no errors. If `available_quantity` is reported missing on the serializer's payload, check `app/serializers/ticket_type_serializer.rb` in the backend and report rather than casting the type away.

Run: `cd frontend && npm run build`
Expected: build succeeds.

- [ ] **Step 5: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/src/app/events/\[id\]/EventDetailClient.tsx frontend/src/types/index.ts
git commit -m "feat(frontend): replace single-tier booking with the multi-tier picker"
```

---

### Task 6: The ticket card

**Files:**
- Create: `frontend/src/components/tickets/TicketCard.tsx`
- Modify: `frontend/package.json` (add `qrcode.react`)
- Test: `frontend/src/__tests__/components/TicketCard.test.tsx`

**Interfaces:**
- Consumes: `Ticket` from Task 1, `ticketService.download` from Task 1
- Produces: `<TicketCard ticket eventName />`

The QR is rendered client-side from the ticket's code. The code — not any image — is the canonical artifact, so the browser and the PDF stay in agreement by construction.

- [ ] **Step 1: Add the QR dependency**

```bash
cd frontend && npm install qrcode.react@^4.2.0
```
Expected: `qrcode.react` appears in `dependencies`.

- [ ] **Step 2: Write the failing test**

Create `frontend/src/__tests__/components/TicketCard.test.tsx`:

```tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import TicketCard from '@/components/tickets/TicketCard';
import { ticketService } from '@/services/orderService';

jest.mock('@/services/orderService', () => ({
  ticketService: { download: jest.fn() },
}));

const mockedDownload = ticketService.download as jest.MockedFunction<typeof ticketService.download>;

const ticket = {
  id: 1,
  code: 'EB-A7X9K2M4P8Q3',
  status: 'issued' as const,
  checked_in_at: null,
  ticket_type_name: 'General Admission',
};

describe('TicketCard', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    global.URL.createObjectURL = jest.fn(() => 'blob:mock');
    global.URL.revokeObjectURL = jest.fn();
  });

  it('shows the code and tier', () => {
    render(<TicketCard ticket={ticket} eventName="Berlin Music Festival" />);

    expect(screen.getByText('EB-A7X9K2M4P8Q3')).toBeInTheDocument();
    expect(screen.getByText('General Admission')).toBeInTheDocument();
  });

  it('renders a QR labelled with the code', () => {
    render(<TicketCard ticket={ticket} eventName="Berlin Music Festival" />);
    expect(screen.getByRole('img', { name: /EB-A7X9K2M4P8Q3/ })).toBeInTheDocument();
  });

  it('downloads a PDF named after the code', async () => {
    mockedDownload.mockResolvedValue(new Blob(['%PDF'], { type: 'application/pdf' }));
    const user = userEvent.setup();
    render(<TicketCard ticket={ticket} eventName="Berlin Music Festival" />);

    await user.click(screen.getByRole('button', { name: /download/i }));

    await waitFor(() => expect(mockedDownload).toHaveBeenCalledWith('EB-A7X9K2M4P8Q3'));
  });

  it('marks a checked-in ticket as used and hides download', () => {
    render(
      <TicketCard
        ticket={{ ...ticket, status: 'checked_in', checked_in_at: '2027-07-15T18:30:00Z' }}
        eventName="Berlin Music Festival"
      />
    );

    expect(screen.getByText(/used/i)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /download/i })).not.toBeInTheDocument();
  });

  it('marks a cancelled ticket as void and hides download', () => {
    render(<TicketCard ticket={{ ...ticket, status: 'cancelled' }} eventName="Berlin Music Festival" />);

    expect(screen.getByText(/void/i)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /download/i })).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd frontend && npx jest src/__tests__/components/TicketCard.test.tsx`
Expected: FAIL — cannot resolve `@/components/tickets/TicketCard`

- [ ] **Step 4: Write the component**

Create `frontend/src/components/tickets/TicketCard.tsx`:

```tsx
"use client";

import { useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { Download, Loader2 } from 'lucide-react';
import clsx from 'clsx';
import { ticketService } from '@/services/orderService';
import type { Ticket } from '@/types/order';

interface TicketCardProps {
  ticket: Ticket;
  eventName: string;
}

export default function TicketCard({ ticket, eventName }: TicketCardProps) {
  const [downloading, setDownloading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const usable = ticket.status === 'issued';

  const handleDownload = async () => {
    setDownloading(true);
    setError(null);

    try {
      const blob = await ticketService.download(ticket.code);
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `ticket-${ticket.code}.pdf`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    } catch {
      setError('Could not download that ticket. Please try again.');
    } finally {
      setDownloading(false);
    }
  };

  return (
    <div className={clsx('border-2 border-black p-5', !usable && 'opacity-50')}>
      <div className="flex items-start gap-5">
        <div className="shrink-0 bg-white p-2" aria-hidden={!usable}>
          <QRCodeSVG
            value={ticket.code}
            size={112}
            level="H"
            role="img"
            aria-label={`QR code for ticket ${ticket.code}`}
          />
        </div>

        <div className="min-w-0 flex-1">
          <p className="text-xs font-bold uppercase tracking-wider text-black/50">{eventName}</p>
          <h3 className="heading-card mt-1 uppercase">{ticket.ticket_type_name}</h3>
          <p className="mt-2 break-all font-mono text-sm font-bold tabular-nums">{ticket.code}</p>

          {ticket.status === 'checked_in' ? (
            <p className="mt-2 text-xs font-bold uppercase tracking-wider">Used at the door</p>
          ) : null}
          {ticket.status === 'cancelled' ? (
            <p className="mt-2 text-xs font-bold uppercase tracking-wider text-[--color-accent]">Void</p>
          ) : null}

          {usable ? (
            <button
              type="button"
              onClick={handleDownload}
              disabled={downloading}
              className="mt-4 inline-flex min-h-11 items-center gap-2 border-2 border-black px-4 py-2 text-xs font-black uppercase tracking-wider transition-colors hover:bg-black hover:text-white disabled:opacity-40"
            >
              {downloading ? (
                <Loader2 className="h-3.5 w-3.5 animate-spin" aria-hidden="true" />
              ) : (
                <Download className="h-3.5 w-3.5" aria-hidden="true" />
              )}
              Download PDF
            </button>
          ) : null}

          {error ? (
            <p role="alert" className="mt-2 text-xs font-bold text-[--color-accent]">
              {error}
            </p>
          ) : null}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd frontend && npx jest src/__tests__/components/TicketCard.test.tsx`
Expected: PASS — 5 passed

- [ ] **Step 6: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/package.json frontend/package-lock.json frontend/src/components/tickets/TicketCard.tsx frontend/src/__tests__/components/TicketCard.test.tsx
git commit -m "feat(frontend): add ticket card with client-rendered QR and PDF download"
```

---

### Task 7: Status badge and order summary card

**Files:**
- Create: `frontend/src/components/orders/OrderStatusBadge.tsx`
- Create: `frontend/src/components/orders/OrderSummaryCard.tsx`
- Test: `frontend/src/__tests__/components/OrderStatusBadge.test.tsx`

**Interfaces:**
- Consumes: `Order`, `OrderStatus` from Task 1
- Produces: `<OrderStatusBadge status />`, `<OrderSummaryCard order />`

- [ ] **Step 1: Write the failing test**

Create `frontend/src/__tests__/components/OrderStatusBadge.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react';
import OrderStatusBadge from '@/components/orders/OrderStatusBadge';

describe('OrderStatusBadge', () => {
  it('labels a paid order as confirmed', () => {
    render(<OrderStatusBadge status="paid" />);
    expect(screen.getByText(/confirmed/i)).toBeInTheDocument();
  });

  it('labels a pending order as awaiting payment', () => {
    render(<OrderStatusBadge status="pending" />);
    expect(screen.getByText(/awaiting payment/i)).toBeInTheDocument();
  });

  it('renders every status without throwing', () => {
    (['pending', 'paid', 'expired', 'cancelled', 'refunded'] as const).forEach((status) => {
      const { unmount } = render(<OrderStatusBadge status={status} />);
      unmount();
    });
  });

  it('does not rely on colour alone', () => {
    render(<OrderStatusBadge status="cancelled" />);
    expect(screen.getByText(/cancelled/i)).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx jest src/__tests__/components/OrderStatusBadge.test.tsx`
Expected: FAIL — cannot resolve the module

- [ ] **Step 3: Write the badge**

Create `frontend/src/components/orders/OrderStatusBadge.tsx`:

```tsx
import clsx from 'clsx';
import type { OrderStatus } from '@/types/order';

/**
 * Each status carries its own words, never colour alone — the accent border is
 * reinforcement, not the message.
 */
const LABELS: Record<OrderStatus, string> = {
  pending: 'Awaiting payment',
  paid: 'Confirmed',
  expired: 'Expired',
  cancelled: 'Cancelled',
  refunded: 'Refunded',
};

const TONE: Record<OrderStatus, string> = {
  pending: 'border-black/40 text-black/60',
  paid: 'border-black bg-black text-white',
  expired: 'border-black/40 text-black/60',
  cancelled: 'border-[--color-accent] text-[--color-accent]',
  refunded: 'border-[--color-accent] text-[--color-accent]',
};

export default function OrderStatusBadge({ status }: { status: OrderStatus }) {
  return (
    <span
      className={clsx(
        'inline-block border-2 px-2.5 py-1 text-xs font-black uppercase tracking-wider',
        TONE[status]
      )}
    >
      {LABELS[status]}
    </span>
  );
}
```

- [ ] **Step 4: Write the summary card**

Create `frontend/src/components/orders/OrderSummaryCard.tsx`:

```tsx
import Link from 'next/link';
import { format } from 'date-fns';
import { Calendar, Ticket as TicketIcon } from 'lucide-react';
import OrderStatusBadge from './OrderStatusBadge';
import type { Order } from '@/types/order';

const money = new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' });

export default function OrderSummaryCard({ order }: { order: Order }) {
  return (
    <Link
      href={`/profile/orders/${order.id}`}
      className="group block border-2 border-black p-5 transition-colors hover:bg-black/5"
    >
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <h3 className="heading-card uppercase group-hover:underline decoration-2 underline-offset-4">
            {order.event.name}
          </h3>

          <div className="mt-2 flex flex-wrap items-center gap-4 text-sm text-black/50">
            <span className="flex items-center gap-1.5">
              <Calendar className="h-3.5 w-3.5" aria-hidden="true" />
              {format(new Date(order.event.date), 'd MMM yyyy, HH:mm')}
            </span>
            <span className="flex items-center gap-1.5">
              <TicketIcon className="h-3.5 w-3.5" aria-hidden="true" />
              {order.ticket_count} {order.ticket_count === 1 ? 'ticket' : 'tickets'}
            </span>
          </div>

          <p className="mt-3 text-xs font-bold uppercase tracking-wider text-black/50">
            {order.reference}
          </p>
        </div>

        <div className="shrink-0 text-right">
          <OrderStatusBadge status={order.status} />
          <p className="mt-2 font-black tabular-nums">{money.format(Number(order.total_amount))}</p>
        </div>
      </div>
    </Link>
  );
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd frontend && npx jest src/__tests__/components/OrderStatusBadge.test.tsx`
Expected: PASS — 4 passed

- [ ] **Step 6: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/src/components/orders/ frontend/src/__tests__/components/OrderStatusBadge.test.tsx
git commit -m "feat(frontend): add order status badge and summary card"
```

---

### Task 8: The orders list page

**Files:**
- Create: `frontend/src/app/profile/orders/page.tsx`
- Test: `frontend/src/__tests__/pages/OrdersPage.test.tsx`

**Interfaces:**
- Consumes: `useOrders` from Task 2, `OrderSummaryCard` from Task 7
- Produces: the `/profile/orders` route

Tabs split on whether the event has happened, not on order status — a cancelled order for a future gig still belongs under Upcoming, because that is where the buyer will look for it.

- [ ] **Step 1: Write the failing test**

Create `frontend/src/__tests__/pages/OrdersPage.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import OrdersPage from '@/app/profile/orders/page';
import { orderService } from '@/services/orderService';

jest.mock('@/services/orderService', () => ({ orderService: { list: jest.fn() } }));
jest.mock('@/components/Navbar', () => () => <nav />);
jest.mock('@/components/Footer', () => () => <footer />);

const mockedList = orderService.list as jest.MockedFunction<typeof orderService.list>;

const future = new Date(Date.now() + 30 * 86_400_000).toISOString();
const past = new Date(Date.now() - 30 * 86_400_000).toISOString();

function order(id: number, name: string, date: string) {
  return {
    id,
    reference: `ORD-00000${id}`,
    status: 'paid',
    total_amount: '59.98',
    ticket_count: 2,
    event: { id: 1, name, date, location: 'Berlin' },
  };
}

function renderPage() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={client}>{children}</QueryClientProvider>
  );
  return render(<OrdersPage />, { wrapper });
}

describe('OrdersPage', () => {
  beforeEach(() => jest.clearAllMocks());

  it('shows a skeleton while loading', () => {
    mockedList.mockReturnValue(new Promise(() => {}) as never);
    renderPage();
    expect(screen.getByTestId('orders-skeleton')).toBeInTheDocument();
  });

  it('lists upcoming orders by default', async () => {
    mockedList.mockResolvedValue({
      orders: [order(1, 'Future Gig', future), order(2, 'Old Gig', past)],
      meta: { page: 1, pages: 1, count: 2 },
    } as never);

    renderPage();

    expect(await screen.findByText('Future Gig')).toBeInTheDocument();
    expect(screen.queryByText('Old Gig')).not.toBeInTheDocument();
  });

  it('switches to past orders', async () => {
    mockedList.mockResolvedValue({
      orders: [order(1, 'Future Gig', future), order(2, 'Old Gig', past)],
      meta: { page: 1, pages: 1, count: 2 },
    } as never);

    const user = userEvent.setup();
    renderPage();
    await screen.findByText('Future Gig');

    await user.click(screen.getByRole('tab', { name: /past/i }));

    expect(screen.getByText('Old Gig')).toBeInTheDocument();
    expect(screen.queryByText('Future Gig')).not.toBeInTheDocument();
  });

  it('offers a route to events when there is nothing to show', async () => {
    mockedList.mockResolvedValue({ orders: [], meta: { page: 1, pages: 0, count: 0 } } as never);

    renderPage();

    expect(await screen.findByText(/no upcoming orders/i)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /browse events/i })).toHaveAttribute('href', '/events');
  });

  it('shows a retry path when the request fails', async () => {
    mockedList.mockRejectedValue(new Error('network down'));

    renderPage();

    expect(await screen.findByRole('alert')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /try again/i })).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx jest src/__tests__/pages/OrdersPage.test.tsx`
Expected: FAIL — cannot resolve `@/app/profile/orders/page`

- [ ] **Step 3: Write the page**

Create `frontend/src/app/profile/orders/page.tsx`:

```tsx
"use client";

import { useMemo, useState } from 'react';
import Link from 'next/link';
import clsx from 'clsx';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import OrderSummaryCard from '@/components/orders/OrderSummaryCard';
import { useOrders } from '@/hooks/useOrders';
import type { Order } from '@/types/order';

type Tab = 'upcoming' | 'past';

export default function OrdersPage() {
  const [tab, setTab] = useState<Tab>('upcoming');
  const { data, isLoading, isError, refetch } = useOrders();

  const { upcoming, past } = useMemo(() => {
    const now = Date.now();
    const orders: Order[] = data?.orders ?? [];

    return {
      upcoming: orders.filter((o) => new Date(o.event.date).getTime() >= now),
      past: orders.filter((o) => new Date(o.event.date).getTime() < now),
    };
  }, [data]);

  const shown = tab === 'upcoming' ? upcoming : past;

  return (
    <>
      <Navbar />

      <main className="mx-auto max-w-4xl px-6 py-16">
        <h1 className="heading-display mb-10">Your orders</h1>

        <div role="tablist" aria-label="Order timeframe" className="mb-8 flex gap-0 border-b-2 border-black">
          {(['upcoming', 'past'] as const).map((value) => (
            <button
              key={value}
              role="tab"
              aria-selected={tab === value}
              onClick={() => setTab(value)}
              className={clsx(
                'min-h-11 px-6 py-3 text-sm font-black uppercase tracking-wider transition-colors',
                tab === value ? 'bg-black text-white' : 'text-black/50 hover:text-black'
              )}
            >
              {value}
              {value === 'upcoming' && upcoming.length > 0 ? ` (${upcoming.length})` : null}
              {value === 'past' && past.length > 0 ? ` (${past.length})` : null}
            </button>
          ))}
        </div>

        {isLoading ? (
          <div data-testid="orders-skeleton" className="space-y-4">
            {[0, 1, 2].map((i) => (
              <div key={i} className="h-32 animate-pulse border-2 border-black/10 bg-black/5" />
            ))}
          </div>
        ) : null}

        {isError ? (
          <div role="alert" className="border-2 border-[--color-accent] p-6">
            <p className="font-bold">We could not load your orders.</p>
            <button
              type="button"
              onClick={() => refetch()}
              className="mt-4 min-h-11 border-2 border-black px-4 py-2 text-xs font-black uppercase tracking-wider hover:bg-black hover:text-white"
            >
              Try again
            </button>
          </div>
        ) : null}

        {!isLoading && !isError && shown.length === 0 ? (
          <div className="border-2 border-black p-10 text-center">
            <p className="text-editorial">No {tab} orders</p>
            <Link
              href="/events"
              className="mt-6 inline-block min-h-11 bg-black px-6 py-3 text-xs font-black uppercase tracking-wider text-white hover:bg-[--color-accent]"
            >
              Browse events
            </Link>
          </div>
        ) : null}

        <div className="space-y-4">
          {shown.map((order) => (
            <OrderSummaryCard key={order.id} order={order} />
          ))}
        </div>
      </main>

      <Footer />
    </>
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && npx jest src/__tests__/pages/OrdersPage.test.tsx`
Expected: PASS — 5 passed

- [ ] **Step 5: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/src/app/profile/orders/page.tsx frontend/src/__tests__/pages/OrdersPage.test.tsx
git commit -m "feat(frontend): add orders list with upcoming and past tabs"
```

---

### Task 9: The cancel modal

**Files:**
- Create: `frontend/src/components/orders/CancelOrderModal.tsx`
- Test: `frontend/src/__tests__/components/CancelOrderModal.test.tsx`

**Interfaces:**
- Consumes: `useCancelOrder` from Task 2, `Order` from Task 1
- Produces: `<CancelOrderModal order open onClose onCancelled />`

Cancelling is irreversible and moves money, so the modal states the refund amount, names the deadline, and requires a deliberate confirmation rather than a single click.

- [ ] **Step 1: Write the failing test**

Create `frontend/src/__tests__/components/CancelOrderModal.test.tsx`:

```tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import CancelOrderModal from '@/components/orders/CancelOrderModal';
import { orderService, OrderError } from '@/services/orderService';

jest.mock('@/services/orderService', () => {
  const actual = jest.requireActual('@/services/orderService');
  return { ...actual, orderService: { cancel: jest.fn() } };
});

const mockedCancel = orderService.cancel as jest.MockedFunction<typeof orderService.cancel>;

const order = {
  id: 4,
  reference: 'ORD-000004',
  status: 'paid' as const,
  total_amount: '59.98',
  cancellable: true,
  event: { id: 1, name: 'Berlin Music Festival', date: new Date(Date.now() + 30 * 86_400_000).toISOString() },
};

function renderModal(props: Record<string, unknown> = {}) {
  const client = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={client}>{children}</QueryClientProvider>
  );

  return render(
    <CancelOrderModal
      order={order as never}
      open
      onClose={jest.fn()}
      onCancelled={jest.fn()}
      {...props}
    />,
    { wrapper }
  );
}

describe('CancelOrderModal', () => {
  beforeEach(() => jest.clearAllMocks());

  it('states the refund amount', () => {
    renderModal();
    expect(screen.getByText(/59,98/)).toBeInTheDocument();
  });

  it('keeps confirm disabled until a reason is chosen', async () => {
    const user = userEvent.setup();
    renderModal();

    const confirm = screen.getByRole('button', { name: /cancel order and refund/i });
    expect(confirm).toBeDisabled();

    await user.selectOptions(screen.getByLabelText(/reason/i), 'change_of_plans');
    expect(confirm).toBeEnabled();
  });

  it('submits the chosen reason', async () => {
    mockedCancel.mockResolvedValue({ ...order, status: 'cancelled' } as never);
    const onCancelled = jest.fn();
    const user = userEvent.setup();
    renderModal({ onCancelled });

    await user.selectOptions(screen.getByLabelText(/reason/i), 'illness');
    await user.click(screen.getByRole('button', { name: /cancel order and refund/i }));

    await waitFor(() => expect(mockedCancel).toHaveBeenCalledWith(4, 'illness'));
    await waitFor(() => expect(onCancelled).toHaveBeenCalled());
  });

  it('renders a typed server failure', async () => {
    mockedCancel.mockRejectedValue(
      new OrderError({ message: 'Cancellation closed on 14 July', code: 'past_cutoff' })
    );
    const user = userEvent.setup();
    renderModal();

    await user.selectOptions(screen.getByLabelText(/reason/i), 'change_of_plans');
    await user.click(screen.getByRole('button', { name: /cancel order and refund/i }));

    expect(await screen.findByRole('alert')).toHaveTextContent(/cancellation window/i);
  });

  it('explains itself and blocks confirmation when the cutoff has passed', () => {
    renderModal({ order: { ...order, cancellable: false } });

    expect(screen.getByRole('button', { name: /cancel order and refund/i })).toBeDisabled();
    expect(screen.getByText(/window for this event has closed/i)).toBeInTheDocument();
  });

  it('closes on escape', async () => {
    const onClose = jest.fn();
    const user = userEvent.setup();
    renderModal({ onClose });

    await user.keyboard('{Escape}');
    expect(onClose).toHaveBeenCalled();
  });

  it('renders nothing when closed', () => {
    renderModal({ open: false });
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx jest src/__tests__/components/CancelOrderModal.test.tsx`
Expected: FAIL — cannot resolve the module

- [ ] **Step 3: Write the modal**

Create `frontend/src/components/orders/CancelOrderModal.tsx`:

```tsx
"use client";

import { useEffect, useState } from 'react';
import { format } from 'date-fns';
import { Loader2, X } from 'lucide-react';
import { useCancelOrder } from '@/hooks/useOrders';
import { OrderError } from '@/services/orderService';
import type { Order } from '@/types/order';

interface CancelOrderModalProps {
  order: Order;
  open: boolean;
  onClose: () => void;
  onCancelled: (order: Order) => void;
}

const REASONS = [
  { value: 'change_of_plans', label: 'My plans changed' },
  { value: 'illness', label: 'Illness' },
  { value: 'travel', label: 'Travel problem' },
  { value: 'bought_by_mistake', label: 'Bought by mistake' },
  { value: 'other', label: 'Something else' },
];

const money = new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' });

export default function CancelOrderModal({ order, open, onClose, onCancelled }: CancelOrderModalProps) {
  const [reason, setReason] = useState('');
  const [error, setError] = useState<string | null>(null);
  const cancelOrder = useCancelOrder();

  useEffect(() => {
    if (!open) return undefined;

    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;

  const handleConfirm = async () => {
    setError(null);

    try {
      const updated = await cancelOrder.mutateAsync({ id: order.id, reason });
      onCancelled(updated);
      onClose();
    } catch (err) {
      setError(err instanceof OrderError ? err.message : 'Something went wrong. Please try again.');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="cancel-title"
        className="w-full max-w-lg border-2 border-black bg-white p-6"
      >
        <div className="flex items-start justify-between gap-4">
          <h2 id="cancel-title" className="heading-section">
            Cancel order
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="flex h-11 w-11 shrink-0 items-center justify-center border-2 border-black hover:bg-black hover:text-white"
          >
            <X className="h-4 w-4" aria-hidden="true" />
          </button>
        </div>

        <p className="mt-4 text-sm">
          You are cancelling all tickets for <strong>{order.event.name}</strong>.
        </p>

        <div className="mt-4 border-2 border-black p-4">
          <p className="text-xs font-bold uppercase tracking-wider text-black/50">Refund amount</p>
          <p className="mt-1 text-2xl font-black tabular-nums">
            {money.format(Number(order.total_amount))}
          </p>
          <p className="mt-2 text-xs text-black/50">
            Refunded to your original payment method. It can take a few days to appear.
          </p>
        </div>

        {order.cancellable ? (
          <p className="mt-3 text-xs text-black/50">
            Cancellation for this event closes before{' '}
            {format(new Date(order.event.date), "d MMM yyyy 'at' HH:mm")}.
          </p>
        ) : (
          <p className="mt-3 border-2 border-[--color-accent] p-3 text-sm font-bold">
            The cancellation window for this event has closed.
          </p>
        )}

        <div className="mt-5">
          <label htmlFor="cancel-reason" className="block text-xs font-bold uppercase tracking-wider">
            Reason
          </label>
          <select
            id="cancel-reason"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            disabled={!order.cancellable || cancelOrder.isPending}
            className="mt-2 min-h-11 w-full border-2 border-black bg-white px-3 py-2 text-sm"
          >
            <option value="">Choose a reason…</option>
            {REASONS.map((r) => (
              <option key={r.value} value={r.value}>
                {r.label}
              </option>
            ))}
          </select>
        </div>

        {error ? (
          <p role="alert" className="mt-4 border-2 border-[--color-accent] p-3 text-sm font-bold">
            {error}
          </p>
        ) : null}

        <div className="mt-6 flex flex-col gap-2 sm:flex-row-reverse">
          <button
            type="button"
            onClick={handleConfirm}
            disabled={!order.cancellable || !reason || cancelOrder.isPending}
            className="flex min-h-11 flex-1 items-center justify-center gap-2 bg-[--color-accent] px-5 py-3 text-xs font-black uppercase tracking-wider text-white disabled:cursor-not-allowed disabled:opacity-30"
          >
            {cancelOrder.isPending ? (
              <>
                <Loader2 className="h-3.5 w-3.5 animate-spin" aria-hidden="true" />
                Cancelling
              </>
            ) : (
              'Cancel order and refund'
            )}
          </button>

          <button
            type="button"
            onClick={onClose}
            disabled={cancelOrder.isPending}
            className="min-h-11 flex-1 border-2 border-black px-5 py-3 text-xs font-black uppercase tracking-wider hover:bg-black hover:text-white"
          >
            Keep my tickets
          </button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && npx jest src/__tests__/components/CancelOrderModal.test.tsx`
Expected: PASS — 7 passed

- [ ] **Step 5: Require a typed confirmation**

The spec asks for a typed confirmation, not just a selected reason. Cancelling refunds money and voids every ticket on the order — it deserves a deliberate keystroke rather than a mis-click.

Replace the `keeps confirm disabled until a reason is chosen` test with:

```tsx
  it('requires both a reason and a typed confirmation', async () => {
    const user = userEvent.setup();
    renderModal();

    const confirm = screen.getByRole('button', { name: /cancel order and refund/i });
    expect(confirm).toBeDisabled();

    await user.selectOptions(screen.getByLabelText(/reason/i), 'change_of_plans');
    expect(confirm).toBeDisabled();

    await user.type(screen.getByLabelText(/type cancel/i), 'CANCEL');
    expect(confirm).toBeEnabled();
  });

  it('accepts the confirmation regardless of case or padding', async () => {
    const user = userEvent.setup();
    renderModal();

    await user.selectOptions(screen.getByLabelText(/reason/i), 'change_of_plans');
    await user.type(screen.getByLabelText(/type cancel/i), '  cancel  ');

    expect(screen.getByRole('button', { name: /cancel order and refund/i })).toBeEnabled();
  });
```

The two tests that already submit must now type the confirmation too — add `await user.type(screen.getByLabelText(/type cancel/i), 'CANCEL');` after the `selectOptions` line in both `submits the chosen reason` and `renders a typed server failure`.

Then in `CancelOrderModal.tsx` add the state:

```tsx
  const [confirmation, setConfirmation] = useState('');
  const confirmed = confirmation.trim().toUpperCase() === 'CANCEL';
```

Add this field immediately after the reason `<select>` block:

```tsx
        <div className="mt-4">
          <label htmlFor="cancel-confirm" className="block text-xs font-bold uppercase tracking-wider">
            Type CANCEL to confirm
          </label>
          <input
            id="cancel-confirm"
            type="text"
            value={confirmation}
            onChange={(e) => setConfirmation(e.target.value)}
            disabled={!order.cancellable || cancelOrder.isPending}
            autoComplete="off"
            className="mt-2 min-h-11 w-full border-2 border-black px-3 py-2 text-sm font-bold uppercase tracking-wider"
          />
        </div>
```

And extend the confirm button's `disabled` to include it:

```tsx
            disabled={!order.cancellable || !reason || !confirmed || cancelOrder.isPending}
```

Run the file again and confirm all 9 tests pass.

- [ ] **Step 6: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/src/components/orders/CancelOrderModal.tsx frontend/src/__tests__/components/CancelOrderModal.test.tsx
git commit -m "feat(frontend): add cancel order modal with refund amount and cutoff"
```

---

### Task 10: The order detail page

**Files:**
- Create: `frontend/src/app/profile/orders/[id]/page.tsx`
- Test: `frontend/src/__tests__/pages/OrderDetailPage.test.tsx`

**Interfaces:**
- Consumes: `useOrder` from Task 2, `TicketCard` from Task 6, `OrderStatusBadge` from Task 7, `CancelOrderModal` from Task 9
- Produces: the `/profile/orders/[id]` route

- [ ] **Step 1: Write the failing test**

Create `frontend/src/__tests__/pages/OrderDetailPage.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import OrderDetailPage from '@/app/profile/orders/[id]/page';
import { orderService } from '@/services/orderService';

jest.mock('@/services/orderService', () => ({ orderService: { get: jest.fn() }, ticketService: { download: jest.fn() } }));
jest.mock('@/components/Navbar', () => () => <nav />);
jest.mock('@/components/Footer', () => () => <footer />);
jest.mock('next/navigation', () => ({ useParams: () => ({ id: '4' }), useRouter: () => ({ push: jest.fn() }) }));

const mockedGet = orderService.get as jest.MockedFunction<typeof orderService.get>;

const paidOrder = {
  id: 4,
  reference: 'ORD-000004',
  status: 'paid',
  payment_status: 'paid',
  total_amount: '59.98',
  cancellable: true,
  ticket_count: 2,
  event: { id: 1, name: 'Berlin Music Festival', date: new Date(Date.now() + 86_400_000).toISOString(), location: 'Berlin Arena' },
  bookings: [
    {
      id: 1,
      quantity: 2,
      total_price: '59.98',
      status: 'confirmed',
      ticket_type: { id: 1, name: 'General Admission', price: '29.99' },
      tickets: [
        { id: 1, code: 'EB-AAAAAAAAAAAA', status: 'issued', checked_in_at: null, ticket_type_name: 'General Admission' },
        { id: 2, code: 'EB-BBBBBBBBBBBB', status: 'issued', checked_in_at: null, ticket_type_name: 'General Admission' },
      ],
    },
  ],
};

function renderPage() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={client}>{children}</QueryClientProvider>
  );
  return render(<OrderDetailPage />, { wrapper });
}

describe('OrderDetailPage', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    global.URL.createObjectURL = jest.fn(() => 'blob:mock');
    global.URL.revokeObjectURL = jest.fn();
  });

  it('renders every ticket in the order', async () => {
    mockedGet.mockResolvedValue(paidOrder as never);
    renderPage();

    expect(await screen.findByText('EB-AAAAAAAAAAAA')).toBeInTheDocument();
    expect(screen.getByText('EB-BBBBBBBBBBBB')).toBeInTheDocument();
  });

  it('shows the reference and total', async () => {
    mockedGet.mockResolvedValue(paidOrder as never);
    renderPage();

    expect(await screen.findByText('ORD-000004')).toBeInTheDocument();
    expect(screen.getByText(/59,98/)).toBeInTheDocument();
  });

  it('opens the cancel modal', async () => {
    mockedGet.mockResolvedValue(paidOrder as never);
    const user = userEvent.setup();
    renderPage();

    await user.click(await screen.findByRole('button', { name: /cancel order/i }));
    expect(screen.getByRole('dialog')).toBeInTheDocument();
  });

  it('hides cancel once the cutoff has passed', async () => {
    mockedGet.mockResolvedValue({ ...paidOrder, cancellable: false } as never);
    renderPage();

    await screen.findByText('ORD-000004');
    expect(screen.queryByRole('button', { name: /cancel order/i })).not.toBeInTheDocument();
  });

  it('hides cancel for an order that is not paid', async () => {
    mockedGet.mockResolvedValue({ ...paidOrder, status: 'pending', cancellable: false } as never);
    renderPage();

    await screen.findByText('ORD-000004');
    expect(screen.queryByRole('button', { name: /cancel order/i })).not.toBeInTheDocument();
  });

  it('explains a pending order rather than showing empty tickets', async () => {
    mockedGet.mockResolvedValue({ ...paidOrder, status: 'pending', bookings: [{ ...paidOrder.bookings[0], tickets: [] }] } as never);
    renderPage();

    expect(await screen.findByText(/issued once your payment is confirmed/i)).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx jest src/__tests__/pages/OrderDetailPage.test.tsx`
Expected: FAIL — cannot resolve `@/app/profile/orders/[id]/page`

- [ ] **Step 3: Write the page**

Create `frontend/src/app/profile/orders/[id]/page.tsx`:

```tsx
"use client";

import { useMemo, useState } from 'react';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import { format } from 'date-fns';
import { ArrowLeft, Calendar, MapPin } from 'lucide-react';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import TicketCard from '@/components/tickets/TicketCard';
import OrderStatusBadge from '@/components/orders/OrderStatusBadge';
import CancelOrderModal from '@/components/orders/CancelOrderModal';
import { useOrder } from '@/hooks/useOrders';
import type { Ticket } from '@/types/order';

const money = new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' });

export default function OrderDetailPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params?.id);
  const { data: order, isLoading, isError } = useOrder(id);
  const [cancelOpen, setCancelOpen] = useState(false);

  const tickets = useMemo<Ticket[]>(
    () => (order?.bookings ?? []).flatMap((booking) => booking.tickets ?? []),
    [order]
  );

  const canCancel = Boolean(order && order.status === 'paid' && order.cancellable);

  return (
    <>
      <Navbar />

      <main className="mx-auto max-w-3xl px-6 py-16">
        <Link
          href="/profile/orders"
          className="mb-8 inline-flex items-center gap-2 text-xs font-black uppercase tracking-wider hover:underline decoration-2 underline-offset-4"
        >
          <ArrowLeft className="h-3.5 w-3.5" aria-hidden="true" />
          All orders
        </Link>

        {isLoading ? (
          <div data-testid="order-skeleton" className="space-y-4">
            <div className="h-24 animate-pulse border-2 border-black/10 bg-black/5" />
            <div className="h-40 animate-pulse border-2 border-black/10 bg-black/5" />
          </div>
        ) : null}

        {isError ? (
          <p role="alert" className="border-2 border-[--color-accent] p-6 font-bold">
            We could not load that order.
          </p>
        ) : null}

        {order ? (
          <>
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="min-w-0">
                <h1 className="heading-section">{order.event.name}</h1>

                <div className="mt-3 flex flex-wrap items-center gap-4 text-sm text-black/50">
                  <span className="flex items-center gap-1.5">
                    <Calendar className="h-3.5 w-3.5" aria-hidden="true" />
                    {format(new Date(order.event.date), "d MMM yyyy 'at' HH:mm")}
                  </span>
                  <span className="flex items-center gap-1.5">
                    <MapPin className="h-3.5 w-3.5" aria-hidden="true" />
                    {order.event.location}
                  </span>
                </div>
              </div>

              <OrderStatusBadge status={order.status} />
            </div>

            <dl className="mt-8 grid grid-cols-2 gap-4 border-y-2 border-black py-5 sm:grid-cols-3">
              <div>
                <dt className="text-xs font-bold uppercase tracking-wider text-black/50">Reference</dt>
                <dd className="mt-1 font-black">{order.reference}</dd>
              </div>
              <div>
                <dt className="text-xs font-bold uppercase tracking-wider text-black/50">Tickets</dt>
                <dd className="mt-1 font-black tabular-nums">{order.ticket_count}</dd>
              </div>
              <div>
                <dt className="text-xs font-bold uppercase tracking-wider text-black/50">Total</dt>
                <dd className="mt-1 font-black tabular-nums">
                  {money.format(Number(order.total_amount))}
                </dd>
              </div>
            </dl>

            <h2 className="heading-card mt-10 uppercase">Your tickets</h2>

            {tickets.length > 0 ? (
              <div className="mt-4 space-y-4">
                {tickets.map((ticket) => (
                  <TicketCard key={ticket.id} ticket={ticket} eventName={order.event.name} />
                ))}
              </div>
            ) : (
              <p className="mt-4 border-2 border-black p-6 text-sm">
                Tickets are issued once your payment is confirmed.
              </p>
            )}

            {canCancel ? (
              <div className="mt-12 border-t-2 border-black pt-6">
                <button
                  type="button"
                  onClick={() => setCancelOpen(true)}
                  className="min-h-11 border-2 border-[--color-accent] px-5 py-3 text-xs font-black uppercase tracking-wider text-[--color-accent] transition-colors hover:bg-[--color-accent] hover:text-white"
                >
                  Cancel order
                </button>
                <p className="mt-2 text-xs text-black/50">
                  Cancelling refunds every ticket on this order.
                </p>
              </div>
            ) : null}

            <CancelOrderModal
              order={order}
              open={cancelOpen}
              onClose={() => setCancelOpen(false)}
              onCancelled={() => setCancelOpen(false)}
            />
          </>
        ) : null}
      </main>

      <Footer />
    </>
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && npx jest src/__tests__/pages/OrderDetailPage.test.tsx`
Expected: PASS — 6 passed

- [ ] **Step 5: Add the download-all action**

The spec calls for a "Download all" action alongside the per-ticket buttons. A buyer with six tickets should not have to click six times.

Add this test to `frontend/src/__tests__/pages/OrderDetailPage.test.tsx`:

```tsx
  it('downloads every usable ticket at once', async () => {
    const { ticketService } = jest.requireMock('@/services/orderService');
    ticketService.download.mockResolvedValue(new Blob(['%PDF'], { type: 'application/pdf' }));
    mockedGet.mockResolvedValue(paidOrder as never);

    const user = userEvent.setup();
    renderPage();

    await user.click(await screen.findByRole('button', { name: /download all/i }));

    await waitFor(() => expect(ticketService.download).toHaveBeenCalledTimes(2));
  });

  it('hides download all when no ticket is usable', async () => {
    mockedGet.mockResolvedValue({
      ...paidOrder,
      status: 'cancelled',
      bookings: [
        {
          ...paidOrder.bookings[0],
          tickets: paidOrder.bookings[0].tickets.map((t) => ({ ...t, status: 'cancelled' })),
        },
      ],
    } as never);

    renderPage();

    await screen.findByText('ORD-000004');
    expect(screen.queryByRole('button', { name: /download all/i })).not.toBeInTheDocument();
  });
```

Add `waitFor` to that file's imports from `@testing-library/react`.

Run them and confirm they fail, then in the page add:

```tsx
import { ticketService } from '@/services/orderService';
```

```tsx
  const [downloadingAll, setDownloadingAll] = useState(false);
  const usableTickets = useMemo(() => tickets.filter((t) => t.status === 'issued'), [tickets]);

  // Sequential rather than parallel: each download is an authenticated request
  // that renders a PDF server-side, and a burst of them for a large order is
  // needless load for no perceptible gain.
  const handleDownloadAll = async () => {
    setDownloadingAll(true);

    try {
      for (const ticket of usableTickets) {
        const blob = await ticketService.download(ticket.code);
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `ticket-${ticket.code}.pdf`;
        document.body.appendChild(link);
        link.click();
        link.remove();
        URL.revokeObjectURL(url);
      }
    } finally {
      setDownloadingAll(false);
    }
  };
```

And render it directly beneath the `Your tickets` heading:

```tsx
            {usableTickets.length > 1 ? (
              <button
                type="button"
                onClick={handleDownloadAll}
                disabled={downloadingAll}
                className="mt-3 inline-flex min-h-11 items-center gap-2 border-2 border-black px-4 py-2 text-xs font-black uppercase tracking-wider hover:bg-black hover:text-white disabled:opacity-40"
              >
                {downloadingAll ? 'Downloading…' : `Download all ${usableTickets.length}`}
              </button>
            ) : null}
```

Run the file again and confirm all 8 tests pass.

- [ ] **Step 6: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add "frontend/src/app/profile/orders/[id]/page.tsx" frontend/src/__tests__/pages/OrderDetailPage.test.tsx
git commit -m "feat(frontend): add order detail page with QR tickets and cancellation"
```

---

### Task 11: Checkout success and cancel

**Files:**
- Modify: `frontend/src/app/checkout/success/page.tsx`
- Modify: `frontend/src/app/checkout/cancel/page.tsx`
- Test: `frontend/src/__tests__/pages/CheckoutSuccess.test.tsx`

**Interfaces:**
- Consumes: `useOrder(id, pollUntilPaid)` from Task 2, `useCheckout` from Task 2

Stripe redirects the buyer back before the webhook has necessarily landed, so success polls rather than assuming. Both pages now key off `order_id`, which `Orders::CheckoutService` puts in its `success_url` and `cancel_url`.

- [ ] **Step 1: Read both pages first**

Run: `cat frontend/src/app/checkout/success/page.tsx frontend/src/app/checkout/cancel/page.tsx`

They currently read `session_id` and `booking_id` and talk about bookings. Keep whatever layout chrome they have; replace the data flow.

- [ ] **Step 2: Write the failing test**

Create `frontend/src/__tests__/pages/CheckoutSuccess.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import CheckoutSuccessPage from '@/app/checkout/success/page';
import { orderService } from '@/services/orderService';

jest.mock('@/services/orderService', () => ({ orderService: { get: jest.fn() } }));
jest.mock('@/components/Navbar', () => () => <nav />);
jest.mock('@/components/Footer', () => () => <footer />);
jest.mock('next/navigation', () => ({
  useSearchParams: () => new URLSearchParams('order_id=4'),
  useRouter: () => ({ push: jest.fn() }),
}));

const mockedGet = orderService.get as jest.MockedFunction<typeof orderService.get>;

function renderPage() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={client}>{children}</QueryClientProvider>
  );
  return render(<CheckoutSuccessPage />, { wrapper });
}

describe('CheckoutSuccessPage', () => {
  beforeEach(() => jest.clearAllMocks());

  it('says it is confirming while the order is still pending', async () => {
    mockedGet.mockResolvedValue({ id: 4, status: 'pending', ticket_count: 2 } as never);
    renderPage();

    expect(await screen.findByText(/confirming your payment/i)).toBeInTheDocument();
  });

  it('celebrates once the order is paid and links to the tickets', async () => {
    mockedGet.mockResolvedValue({ id: 4, status: 'paid', ticket_count: 2, reference: 'ORD-000004' } as never);
    renderPage();

    expect(await screen.findByText(/you're going/i)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /view your tickets/i })).toHaveAttribute(
      'href',
      '/profile/orders/4'
    );
  });
});
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd frontend && npx jest src/__tests__/pages/CheckoutSuccess.test.tsx`
Expected: FAIL — the page still reads `session_id` and renders no such copy

- [ ] **Step 4: Rewrite the success page**

Replace `frontend/src/app/checkout/success/page.tsx` with:

```tsx
"use client";

import { Suspense } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { CheckCircle2, Loader2 } from 'lucide-react';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import { useOrder } from '@/hooks/useOrders';

function SuccessBody() {
  const params = useSearchParams();
  const orderId = Number(params.get('order_id'));

  // Stripe redirects before the webhook necessarily lands, so poll rather than
  // declaring failure on a payment that is merely still in flight.
  const { data: order } = useOrder(orderId, true);
  const paid = order?.status === 'paid';

  return (
    <main className="mx-auto max-w-2xl px-6 py-24 text-center">
      {paid ? (
        <>
          <CheckCircle2 className="mx-auto h-12 w-12" aria-hidden="true" />
          <h1 className="heading-display mt-6">You&rsquo;re going</h1>
          <p className="mt-4 text-editorial">
            {order.ticket_count} {order.ticket_count === 1 ? 'ticket is' : 'tickets are'} on the way to
            your inbox.
          </p>
          <p className="mt-2 text-xs font-bold uppercase tracking-wider text-black/50">
            {order.reference}
          </p>

          <Link
            href={`/profile/orders/${order.id}`}
            className="mt-10 inline-block min-h-11 bg-black px-8 py-4 text-xs font-black uppercase tracking-wider text-white hover:bg-[--color-accent]"
          >
            View your tickets
          </Link>
        </>
      ) : (
        <>
          <Loader2 className="mx-auto h-12 w-12 animate-spin" aria-hidden="true" />
          <h1 className="heading-section mt-6">Confirming your payment</h1>
          <p className="mt-4 text-sm text-black/50">
            This usually takes a few seconds. You can leave this page — your tickets will be emailed
            either way.
          </p>
          <Link
            href="/profile/orders"
            className="mt-8 inline-block text-xs font-black uppercase tracking-wider hover:underline decoration-2 underline-offset-4"
          >
            Go to your orders
          </Link>
        </>
      )}
    </main>
  );
}

export default function CheckoutSuccessPage() {
  return (
    <>
      <Navbar />
      <Suspense fallback={<div className="py-24 text-center">Loading…</div>}>
        <SuccessBody />
      </Suspense>
      <Footer />
    </>
  );
}
```

- [ ] **Step 5: Rewrite the cancel page**

Replace `frontend/src/app/checkout/cancel/page.tsx` with:

```tsx
"use client";

import { Suspense, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { Loader2 } from 'lucide-react';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import { useCheckout } from '@/hooks/useOrders';
import { OrderError } from '@/services/orderService';

function CancelBody() {
  const params = useSearchParams();
  const orderId = Number(params.get('order_id'));
  const checkout = useCheckout();
  const [error, setError] = useState<string | null>(null);

  const resume = async () => {
    setError(null);

    try {
      const session = await checkout.mutateAsync(orderId);
      window.location.href = session.checkout_url;
    } catch (err) {
      setError(err instanceof OrderError ? err.message : 'Could not reopen checkout.');
    }
  };

  return (
    <main className="mx-auto max-w-2xl px-6 py-24 text-center">
      <h1 className="heading-section">Checkout cancelled</h1>
      <p className="mt-4 text-sm text-black/50">
        Nothing was charged. We are holding your tickets for 15 minutes from when you started — after
        that they go back on sale.
      </p>

      {error ? (
        <p role="alert" className="mx-auto mt-6 max-w-md border-2 border-[--color-accent] p-3 text-sm font-bold">
          {error}
        </p>
      ) : null}

      <div className="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
        {Number.isFinite(orderId) && orderId > 0 ? (
          <button
            type="button"
            onClick={resume}
            disabled={checkout.isPending}
            className="inline-flex min-h-11 items-center justify-center gap-2 bg-black px-8 py-4 text-xs font-black uppercase tracking-wider text-white hover:bg-[--color-accent] disabled:opacity-40"
          >
            {checkout.isPending ? (
              <Loader2 className="h-3.5 w-3.5 animate-spin" aria-hidden="true" />
            ) : null}
            Resume checkout
          </button>
        ) : null}

        <Link
          href="/events"
          className="min-h-11 border-2 border-black px-8 py-4 text-xs font-black uppercase tracking-wider hover:bg-black hover:text-white"
        >
          Browse events
        </Link>
      </div>
    </main>
  );
}

export default function CheckoutCancelPage() {
  return (
    <>
      <Navbar />
      <Suspense fallback={<div className="py-24 text-center">Loading…</div>}>
        <CancelBody />
      </Suspense>
      <Footer />
    </>
  );
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `cd frontend && npx jest src/__tests__/pages/CheckoutSuccess.test.tsx`
Expected: PASS — 2 passed

- [ ] **Step 7: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/src/app/checkout/ frontend/src/__tests__/pages/CheckoutSuccess.test.tsx
git commit -m "feat(frontend): poll for payment confirmation and offer checkout resume"
```

---

### Task 12: Redirect the old bookings route

**Files:**
- Modify: `frontend/src/app/profile/bookings/page.tsx`

**Interfaces:**
- Consumes: nothing
- Produces: a permanent redirect from `/profile/bookings` to `/profile/orders`

- [ ] **Step 1: Replace the page with a redirect**

Replace the entire contents of `frontend/src/app/profile/bookings/page.tsx` with:

```tsx
import { redirect } from 'next/navigation';

/**
 * Bookings became line items inside an order. Any bookmark or emailed link to
 * the old page should still land somewhere useful.
 */
export default function BookingsRedirect() {
  redirect('/profile/orders');
}
```

- [ ] **Step 2: Verify the redirect resolves**

Run: `cd frontend && npx tsc --noEmit`
Expected: no errors.

Run: `cd frontend && npm run build`
Expected: build succeeds and `/profile/bookings` appears in the route list.

- [ ] **Step 3: Update any internal links**

Run: `grep -rn "profile/bookings" frontend/src/ --include=*.tsx --include=*.ts`

Point every result at `/profile/orders` instead. Check `Navbar.tsx` in particular, which links to the profile area.

- [ ] **Step 4: Lint and commit**

```bash
cd frontend && npm run lint
cd .. && git add frontend/src/app/profile/bookings/page.tsx frontend/src/components/Navbar.tsx
git commit -m "feat(frontend): redirect the old bookings route to orders"
```

---

### Task 13: Retire the dead booking service and verify

**Files:**
- Modify: `frontend/src/services/bookingService.ts`
- Test: the whole suite

**Interfaces:**
- Consumes: everything built above
- Produces: nothing

Three methods on `bookingService` call endpoints the backend removed. They cannot work, and leaving them invites someone to call them.

- [ ] **Step 1: Find every remaining caller**

Run: `grep -rn "bookingService" frontend/src/ --include=*.tsx --include=*.ts`

Every call site should now be gone except the service itself. If any component still imports it, migrate that call to `orderService` before continuing — do not leave a caller pointing at a dead endpoint.

- [ ] **Step 2: Remove the dead methods**

In `frontend/src/services/bookingService.ts`, delete `createBooking` (POST `/events/:id/bookings`), the Stripe session helper (POST `/checkout/sessions`), and `cancelBooking` (PATCH `/bookings/:id/cancel`).

Keep only what still maps to a live endpoint: the read of `/users/bookings` and the read of `/bookings/:id`, if anything still consumes them. If nothing does, delete the file entirely and remove its imports.

State in your report which methods you kept and why.

- [ ] **Step 3: Verify nothing references a removed endpoint**

Run: `grep -rnE "events/.*/bookings|checkout/sessions|bookings/.*cancel" frontend/src/ || echo "No dead endpoint references remain."`
Expected: `No dead endpoint references remain.`

- [ ] **Step 4: Run the whole frontend suite**

Run: `cd frontend && npx jest`
Expected: all suites pass. Record the total.

- [ ] **Step 5: Typecheck and build**

Run: `cd frontend && npx tsc --noEmit && npm run build`
Expected: no type errors, build succeeds.

- [ ] **Step 6: Lint the whole frontend**

Run: `cd frontend && npm run lint`
Expected: clean, or only offences that predate this plan. Report any pre-existing ones separately from any you introduced.

- [ ] **Step 7: Commit**

```bash
cd .. && git add frontend/src/services/bookingService.ts
git commit -m "chore(frontend): retire booking service methods with no live endpoint"
```

---

## Manual verification

Automated tests do not prove the journey works against the real API. After Task 13, run the stack and walk it once by hand:

```bash
docker compose up -d
```

1. Sign in, open an event with two tiers, and add tickets from both. Confirm the subtotal updates and the cap disables the steppers.
2. Click **Get tickets**, complete Stripe test checkout (card `4242 4242 4242 4242`).
3. Confirm the success page polls, then flips to "You're going".
4. Open the order, confirm one QR per ticket, and download a PDF. Scan the QR with a phone — it must read `EB-…`, matching the code printed beneath it.
5. Cancel the order. Confirm the refund amount shown matches the total, and that the tickets are marked void afterwards.
6. Start another order and abandon it at Stripe. Confirm `/checkout/cancel` offers **Resume checkout** and that resuming returns you to the same Stripe session.

Record anything that behaves differently from the tests' expectations — that gap is exactly what an integration defect looks like, and Plan 1's Task 19 showed the suite can be entirely green while a whole path is broken.

---

## What this plan does not cover

- **The waitlist** (spec §7.5 and §11's "Join waitlist" action). Sold-out tiers show plain "Sold out" here. Plan 3 adds the join/claim flow and the CTA.
- **Organiser check-in UI.** The backend exposes check-in as an API only, by explicit decision. There is no scanner page.
- **Ticket transfer.** Out of scope by decision in the design spec.
- **Dropping the superseded Stripe columns** from `bookings`. Backend cleanup, Plan 3.
