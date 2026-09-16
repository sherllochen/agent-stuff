---
name: react-query-endpoint
description: 'Guideline for integrating backend API endpoints using React Query in this repo (web/src/). Use when asked to add a new API function, useQuery hook, useMutation hook, or their tests.'
---

# React Query Endpoint Integration

## Feature directory structure

Each feature has these files for backend integration:

```
web/src/{featureName}/
├── api.ts                              # Fetch functions — one per endpoint
├── api.test.ts                         # Tests for each api function
├── hooks/
│   ├── use{Resource}Query.ts           # useQuery hooks
│   ├── use{Resource}Query.test.ts
│   ├── use{Action}Mutation.ts          # useMutation hooks
│   └── use{Action}Mutation.test.ts
```

For larger features, hooks may live in a flat `queries.ts` / `mutations.ts` file instead.

## API functions (`api.ts`)

Import `request` and `apiRoot` at the top:

```typescript
import {apiRoot} from 'api/apiRoot';
import request from 'api/request';
```

Each function wraps a single endpoint and returns a typed Promise:

```typescript
// GET — no options needed
export function fetchThing(thingId: string): Promise<ThingResponse> {
  return request(`${apiRoot}/things/${thingId}`);
}

// GET with query params
export function fetchThings(page?: number): Promise<ThingsResponse> {
  return request(`${apiRoot}/things`, {
    data: {page},
  });
}

// POST with JSON body
export function createThing(payload: CreateThingPayload): Promise<ThingResponse> {
  return request(`${apiRoot}/things`, {
    method: 'POST',
    data: payload,
  });
}

// PATCH
export function updateThing(thingId: string, payload: UpdateThingPayload): Promise<ThingResponse> {
  return request(`${apiRoot}/things/${thingId}`, {
    method: 'PATCH',
    data: payload,
  });
}

// DELETE
export function deleteThing(thingId: string): Promise<void> {
  return request(`${apiRoot}/things/${thingId}`, {
    method: 'DELETE',
  });
}
```

Key conventions:

- GET is the default — omit `method` for GET-only calls
- Pass query params via `data:` even for GET requests
- Use typed return values (`Promise<ThingResponse>`) — define the response type above the function
- Export all functions; they are mocked in tests with `jest.mock('./api')`

## API tests (`api.test.ts`)

```typescript
import request from 'api/request';
import * as api from './api';

jest.mock('api/request');

describe('api', () => {
  describe('featureName', () => {
    describe('fetchThing()', () => {
      it('makes a request to the correct URI', () => {
        api.fetchThing('123');
        expect(request).toHaveBeenCalledWith('/api/things/123');
      });
    });

    describe('createThing()', () => {
      it('makes a request to the correct URI with the payload', () => {
        api.createThing({name: 'My Thing'});
        expect(request).toHaveBeenCalledWith('/api/things', {
          method: 'POST',
          data: {name: 'My Thing'},
        });
      });
    });

    describe('updateThing()', () => {
      it('makes a request to the correct URI', () => {
        api.updateThing('123', {name: 'Updated'});
        expect(request).toHaveBeenCalledWith('/api/things/123', {
          method: 'PATCH',
          data: {name: 'Updated'},
        });
      });
    });
  });
});
```

Key conventions:

- `jest.mock('api/request')` mocks the module; no setup needed — just assert `toHaveBeenCalledWith`
- One `describe` per function
- Test the URI, method, and data shape
- Do not test the return value — that belongs to the hook tests

## useQuery hooks

Use the modern object-syntax form:

```typescript
import {useQuery} from 'react-query';
import {ThingResponse, fetchThing} from '../api';

export function useThingQuery(thingId: string) {
  return useQuery<ThingResponse, APIError>({
    queryKey: ['featureName', 'thing', thingId],
    queryFn: async () => fetchThing(thingId),
  });
}
```

### Query key structure

- Always start with the feature namespace string: `['featureName', ...]`
- Add a resource name as the second segment: `['featureName', 'thing']`
- Append IDs or filter params that make the query unique:
  - By ID: `['featureName', 'thing', thingId]`
  - By params object: `['featureName', 'things', {page, filter}]`
- Keep keys consistent across queries and mutations — invalidation depends on prefix matching

### Options

```typescript
// Only run when a value is available
useQuery({
  queryKey: ['featureName', 'thing', id],
  queryFn: async () => fetchThing(id),
  enabled: id != null,
});

// Cache indefinitely (e.g. reference data)
useQuery({
  queryKey: ['featureName', 'config'],
  queryFn: async () => fetchConfig(),
  staleTime: Infinity,
});

// Cache for 5 minutes
useQuery({
  queryKey: ['featureName', 'summary'],
  queryFn: async () => fetchSummary(),
  staleTime: 300000,
});

// Manual trigger (call refetch() yourself)
useQuery({
  queryKey: ['featureName', 'lookup'],
  queryFn: async () => fetchLookup(),
  enabled: false,
});
```

## useQuery tests

```typescript
import {renderHookWithProviders as renderHook} from 'support';
import * as api from '../api';
import {useThingQuery} from './useThingQuery';

jest.mock('./../api');

describe('useThingQuery', () => {
  beforeEach(() => {
    jest.mocked(api.fetchThing).mockResolvedValue({id: '123', name: 'My Thing'});
  });

  it('is successful', async () => {
    const {result, waitFor} = renderHook(() => useThingQuery('123'));

    expect(result.current.data).toBeUndefined();

    await waitFor(() => result.current.isSuccess);

    expect(result.current.isSuccess).toBe(true);
    expect(api.fetchThing).toHaveBeenCalled();
    expect(result.current.data).toEqual({id: '123', name: 'My Thing'});
  });
});
```

Key conventions:

- `jest.mock('./../api')` — relative path with `./` prefix, matches the import in the hook
- Use `jest.mocked(api.fn).mockResolvedValue(...)` (preferred over casting `as jest.Mock`)
- `renderHookWithProviders` imported as `renderHook` from `support`
- Assert `data` is `undefined` before resolution, then `await waitFor(() => result.current.isSuccess)`
- If the hook has an `enabled` condition, test the idle/disabled case separately

### Testing disabled state

```typescript
it('is idle when id is not provided', () => {
  const {result} = renderHook(() => useThingQuery(undefined));

  expect(result.current.isIdle).toBe(true);
  expect(result.current.data).toBeUndefined();
});
```

## useMutation hooks

```typescript
import {useMutation, useQueryClient} from 'react-query';
import {createThing} from '../api';

export function useCreateThingMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: createThing,
    onSuccess: () => {
      queryClient.invalidateQueries(['featureName', 'things']);
    },
  });
}
```

### Cache update strategies

```typescript
// Invalidate — refetch from server
onSuccess: () => {
  queryClient.invalidateQueries(['featureName', 'things']);
};

// Remove and refetch — use when you want no stale data shown
onSuccess: () => {
  queryClient.removeQueries(['featureName', 'currentThing']);
};

// Optimistic set — update cache directly with returned data
onSuccess: result => {
  queryClient.setQueryData(['featureName', 'thing', result.id], result);
};

// Invalidate multiple caches at once
onSuccess: async () => {
  await Promise.all([
    queryClient.invalidateQueries(['featureName', 'things']),
    queryClient.invalidateQueries(['featureName', 'summary']),
  ]);
};
```

### Passing callbacks from the call site

When the component needs to react to success/error, accept callbacks as part of the mutation variables:

```typescript
type DeleteThingVariables = {
  thingId: string;
  onSuccess?: () => void;
};

export function useDeleteThingMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({thingId}: DeleteThingVariables) => deleteThing(thingId),
    onSuccess: (_, {onSuccess}) => {
      onSuccess?.();
      queryClient.invalidateQueries(['featureName', 'things']);
    },
  });
}
```

### Error handling

```typescript
import {createFlashError} from 'components/Flash';

return useMutation({
  mutationFn: createThing,
  onError: () => {
    createFlashError('Something went wrong. Please try again later.');
  },
});
```

## useMutation tests

```typescript
import {renderHookWithProviders as renderHook} from 'support';
import * as api from '../api';
import {useCreateThingMutation} from './useCreateThingMutation';

jest.mock('./../api');

describe('useCreateThingMutation', () => {
  beforeEach(() => {
    jest.mocked(api.createThing).mockResolvedValue({id: '123', name: 'My Thing'});
  });

  it('calls the correct api function', async () => {
    const {result, waitFor} = renderHook(() => useCreateThingMutation());

    result.current.mutate({name: 'My Thing'});

    await waitFor(() => result.current.isSuccess);

    expect(api.createThing).toHaveBeenCalledWith({name: 'My Thing'});
  });
});
```
