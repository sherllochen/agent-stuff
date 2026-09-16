---
name: enzyme-to-rtl
description: Migrates Enzyme tests to React Testing Library (RTL) in this codebase. Use when asked to migrate, refactor, or rewrite Enzyme tests.
---

## Core principles

- Test user-visible behaviour, not implementation details.
- Prefer accessible queries (role/label/text) over `data-testid` (last resort).
- Simulate real user actions with `userEvent`; never call component handlers directly.
- Remove `// @ts-nocheck`; keep all tests fully typed.

## Imports

```tsx
import {screen, waitFor} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {renderWithProviders as render} from 'support';
import {form, router, fieldErrors} from 'support/fixtures'; // when needed for unconnected components
```

## Setup pattern

```tsx
type Props = React.ComponentProps<typeof MyComponent>;

const props: Props = {
  /* defaults */
};

const setup = (override: Partial<Props> = {}) => render(<MyComponent {...props} {...override} />);

beforeEach(() => {
  jest.clearAllMocks();
  // set default mocks here
});
```

- Override per test via `setup({prop: value})`; never mutate the shared `props` object.

## Connected components

- For `connectContainer` components, test the **default export** and pass Redux state via `render(<Component />, {store})`.
- When testing an unwrapped component, inject `form`/`router` fixtures manually.
- Pass a store override object as the second arg to `setup` to exercise different Redux states.

## Mocking

```tsx
jest.mock('path/to/module');

beforeEach(() => {
  jest.clearAllMocks();
  jest.mocked(someHook).mockReturnValue({data, isLoading: false, isError: false, refetch: jest.fn()});
});
```

- Use `jest.mocked()` for type-safe access to mocked functions.
- For React Query hooks, mock the full return shape: `{data, isLoading, isError, refetch}`.

## Query priority

1. `getByRole` (with `name` option)
2. `getByLabelText`
3. `getByText`
4. `getByDisplayValue`
5. `getByTestId` — last resort only

- Use `queryBy*` to assert absence, `findBy*` for async appearance.

## Interactions

```tsx
await userEvent.click(screen.getByRole('button', {name: 'Submit'}));
await userEvent.type(screen.getByLabelText('Email'), 'user@example.com');
await userEvent.clear(screen.getByLabelText('Amount'));
```

- Always `await userEvent.*`.
- Replace Enzyme `setProps` with a new `setup(overrides)` call.

## Async assertions

```tsx
await waitFor(() => expect(mockFn).toHaveBeenCalledWith('value'));
```

- Wrap async expectations in `waitFor`.
- Loading state: mock an unresolved promise or `isLoading: true`; assert the loader is present.
- Error state: mock a rejected promise or `isError: true`; assert error UI.

## Modals / portals

```tsx
beforeEach(() => {
  const modal = document.createElement('div');
  modal.id = 'modal';
  document.body.appendChild(modal);
});

afterEach(() => {
  document.getElementById('modal')?.remove();
});
```

Then query/assert modal content via normal RTL queries.

## Custom matchers

- `toHaveIndeterminateLoader()` — asserts presence of the spinner (`data-semantic="indeterminate-loader"`).

## Common replacements

| Enzyme                                       | RTL                                           |
| -------------------------------------------- | --------------------------------------------- |
| `mountWithProviders`                         | `renderWithProviders`                         |
| `wrapper.find(...)`                          | `screen.getBy*` / `screen.queryBy*`           |
| `wrapper.setProps(...)`                      | re-call `setup({...})`                        |
| `simulate('click')` / calling props directly | `await userEvent.click(...)`                  |
| `act(...)`                                   | usually unnecessary — rely on RTL + `waitFor` |
| `shallow(...)`                               | full `render(...)`                            |

## Checklist

- [ ] Update imports; remove `@ts-nocheck`.
- [ ] Add typed `Props`, default `props` const, and `setup` helper.
- [ ] `jest.mock` all dependencies; set defaults in `beforeEach` after `clearAllMocks`.
- [ ] Swap Enzyme queries for RTL queries (role/label/text first).
- [ ] Swap Enzyme interactions for `await userEvent.*`.
- [ ] Wrap async expectations in `waitFor`; assert loading/error states.
- [ ] Use custom matchers where applicable (e.g. `toHaveIndeterminateLoader()`).
- [ ] Run `yarn test <file>` and `yarn tsc --noEmit <file>` to verify.
