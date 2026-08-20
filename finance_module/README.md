# Personal Finance module

This is an original Rails feature pack for a host panel. It does not copy or depend on Maybe Finance.

## Host contract

The host application must have a `User` model and central authentication. Mount these routes under the authenticated panel area, then set `PersonalFinance.current_user_resolver` once during initialization:

```ruby
PersonalFinance.current_user_resolver = ->(controller) { Current.user }
```

The resolver must return the authenticated panel user. Never resolve a user from an `id` sent by the browser.

Install migrations in the host application, then add `has_many` associations to `User` only if the host needs reverse navigation. The module already enforces ownership from every controller query.

## What is included

- Manual accounts, categories and income/expense/transfer transactions.
- Monthly budgets and per-category allocations.
- Savings goals and a purchase affordability calculator.
- Controller-level authentication and user scoping for every resource.

## What the host should provide

- `ApplicationController` with normal Rails CSRF protection enabled.
- A signed, `HttpOnly`, `Secure` (production) and `SameSite=Lax` or stricter session cookie.
- A `users` table with UUID primary keys. If the host uses bigint IDs, change `type: :uuid` in the migrations before running them.

