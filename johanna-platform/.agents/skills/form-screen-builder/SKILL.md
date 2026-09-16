---
name: form-screen-builder
description: 'Guideline for building or updating form screens in web/src. Use when asked to add inline validation, button sections, fixed content-to-action gaps, custom input error presentation, selfManagedForm field configs, or web/native-aware form layouts.'
---

# Form Screen Builder

Use this skill when building or updating form-like screens in `web/src/`, especially when the work involves:

- `selfManagedForm`, `validators`, or `Form`
- inline field validation messages
- custom input components with local error presentation
- fixed spacing between content and action sections
- web/native layout differences when using `FullHeightStack`
- focused UI tests for validation and submit flows

## Preferred architecture

For screens that already live in the legacy/shared form system, prefer this stack:

- `selfManagedForm({fields})(Screen)`
- field definitions with `validators.*`
- `Form` for submit handling
- screen-level submit logic in `form.validate(...)`

Keep validation rules in the field config, not inside the input component.

Example shape:

```tsx
const fields = {
  accountName: {
    initialValue: '',
    label: 'Account name',
    validator: validators.string({
      isRequired: true,
      invalidCharacters: SOME_REGEX,
      invalidCharactersError: 'Account name cannot include emojis',
      maxLength: 50,
      maxLengthError: 'Account name cannot be longer than 50 characters',
    }),
  },
};

export default selfManagedForm({fields})(MyScreen);
```

## Inline error pattern

When a custom input needs an inline error row with an icon:

- keep the validation state in the screen/form field (`fields.someField.error`)
- render the inline error near the field
- prefer field-local layout over outer page layout hacks

Recommended pattern:

```tsx
<Box position="relative" pb={5}>
  <CustomInput ... />

  {error ? (
    <HStack position="absolute" top={`calc(100% + ${theme.legacy.spacing.tight})`} spacing={2}>
      <ErrorIcon />
      <Text variant="body1.medium" color="critical.foreground" role="alert">
        {error}
      </Text>
    </HStack>
  ) : null}
</Box>
```

Why:

- the error belongs to the field, not the page section
- the button area does not jump when the error appears
- the outer content-to-action gap stays stable

If you move error rendering into a custom input component, make that API reusable, e.g. `errorMessage`, `error`, optional icon support. Do not move screen-specific validation logic into the input.

## Content-to-action spacing

If the screen needs an explicit fixed gap between the form content and the action area, set it explicitly on the layout container.

Use `gap`, not ad hoc spacer boxes.

Example:

```tsx
<FullHeightStack maxW="580px" marginX="auto" gap={20}>
  <Stack spacing={8}>...</Stack>
  <Stack>...</Stack>
</FullHeightStack>
```

`gap={20}` is Chakra spacing scale, which maps to `80px`.

## FullHeightStack behavior

`FullHeightStack` is native-aware.

- on web, it should behave like normal flow (`justifyContent="flex-start"` by default)
- inside `.native-wrapped`, it applies viewport-based `minHeight` and `justifyContent: 'space-between'`

Implications:

- a fixed `gap` is exact on web
- in native, `gap` still applies, but `space-between` can increase the final visible separation
- if you need an exact fixed gap everywhere, do not rely on native `space-between`; override or use an inner layout container

## Theme and spacing usage

- prefer Chakra spacing props (`gap`, `pb`, `spacing`) over margin hacks
- prefer theme tokens like `color="fg.secondary"` or `color="critical.foreground"`
- when absolute positioning needs a local offset, prefer theme spacing values where practical, e.g. `theme.legacy.spacing.tight`

## Testing guidance

Prefer focused screen tests that cover:

- screen title/description rendering
- button enabled/disabled state
- successful submit tracking or callback behavior
- validation errors after the actual trigger used by the screen

Match the test to the real interaction model:

- if validation happens on submit, click submit before asserting errors
- if the input does not enforce `maxLength`, use `userEvent.type('a'.repeat(51))`
- if a custom inline SVG is used, do not assert repo-shared icon classnames unless the shared `Icon` component is actually used

## Anti-patterns

- do not use outer spacer boxes to fake fixed page gaps
- do not subtract local error height from page section gap values
- do not push page-level layout concerns into validation logic
- do not assume `FullHeightStack` behaves the same on web and native
- do not write tests for a different validation timing model than the implementation