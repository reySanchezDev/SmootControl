---
trigger: always_on
---

# Generic Flutter Project - Coding Standards & Architecture Rules

> **Critical**: These rules are **mandatory** for all code contributions. Violations must be corrected before merging.


## 0. Assistant Communication & Output Rules (MANDATORY)

These rules apply to the AI agent (Antigravity) whenever it responds or delivers work for this project.

- **Language**: Always respond in **Spanish**.
- **Brevity**: Be **short, precise, and actionable**. Avoid unnecessary explanations; prioritize steps, commands, and file paths.
- **No Guessing**: Never invent details. If information is missing, state assumptions explicitly or ask for the minimum required input.
- **Consistency**: Use the project’s terminology and established naming conventions; do not introduce new terms without justification.

## 1. Architecture Patterns

### 1.1 Feature-First Structure

We organize code by **feature**, not by layer. This ensures scalability and modularity.

- **Rule**: Create a root folder for every major feature in `lib/features/`.
- **Example**: `auth`, `profile`, `feed`, `settings`.

### 1.2 Clean Architecture Layers

Inside *every* feature folder, you must implement strict **Clean Architecture** layers:

```
lib/features/<feature_name>/
├── domain/              # PURE DART. Business Rules & Entities.
│   ├── entities/        # Immutable model objects.
│   ├── repositories/    # ABSTRACT interfaces (contracts).
│   └── services/        # Domain logic/use-cases.
├── data/                # DATA HANDLERS. API, DB, DTOs.
│   ├── models/          # DTOs (Data Transfer Objects).
│   ├── repositories/    # CONCRETE implementations of interfaces.
│   └── datasources/     # Remote/Local data sources (Http, Sqlite).
├── presentation/        # FLUTTER UI. Visuals & State.
│   ├── bloc/            # State Management (Events, States).
│   ├── pages/           # Scaffold widgets (Screens).
│   └── widgets/         # Reusable components.
```

### 1.3 The Repository Pattern

Strictly decouple business logic from data retrieval.

1.  **Domain Definition**: Define the interface `abstract class IFeatureRepository` in `domain/repositories/`.
2.  **Data Implementation**: Implement the class `class FeatureRepository implements IFeatureRepository` in `data/repositories/`.
3.  **Dependency**: The **Presentation** layer (BLoC) must **ONLY** depend on the **Domain Interface**. It must NEVER know about the Data implementation.

### 1.4 Dependency Rules (CRITICAL)

```
Presentation → Application (BLoC) → Domain ← Data
```

- ✅ **Allowed**: `presentation` imports `bloc`, `bloc` imports `domain`, `data` imports `domain`.
- ❌ **Forbidden**: `domain` imports anything from outside, `data` imports `presentation`, `bloc` imports `data`.

## 2. Code Harmonization (CRITICAL)

**Consistency is Key.** All features must look and behave identically in terms of code structure.

- **Structural Harmony**: If Feature A strictly separates `entities` and `models`, Feature B cannot mix them.
- **Pattern Harmony**: If one BLoC uses `Sealed Classes` for state, **ALL** BLoCs must use Sealed Classes.
- **Naming Harmony**:
    - Repositories: `IFeatureRepository`, `FeatureRepository`.
    - BLoCs: `FeatureBloc`, `FeatureEvent`, `FeatureState`.
    - Pages: `FeaturePage`.

## 3. Design System (MANDATORY)

### Typography - NEVER use `Text()` directly

Create and use a standardized text widget (e.g., `AppText` or `DesignSystemText`).

```dart
// ✅ CORRECT
AppText('Title', variant: TextVariant.titleLarge)

// ❌ WRONG
Text('Title', style: TextStyle(fontSize: 24))
```

### Colors - NEVER hardcode colors

Use the `Theme.of(context).colorScheme` or a dedicated semantic color extension.

```dart
// ✅ CORRECT
Container(color: Theme.of(context).colorScheme.primary)

// ❌ WRONG
Container(color: Colors.blue)
Container(color: Color(0xFF123456))
```

### Spacing

Use standard spacing constants or 8-point grid increments.

```dart
const SizedBox(height: 8)
const SizedBox(height: 16)
const EdgeInsets.all(16)
```


### Layout & Information Architecture (MANDATORY)

- **Logical field order**: Inputs must follow a natural sequence (e.g., identity → contact → details → confirmation).
- **Grouping**: Group related fields into clearly separated sections with headings (e.g., “Datos del cliente”, “Detalles del préstamo”).
- **Required vs optional**: Required fields must be visually clear (label, hint, and validation message).
- **Validation placement**: Show validation close to the field, with a specific message and a corrective hint.
- **Focus flow**: Keyboard/tab order must match the visual order; avoid jumps that confuse the user.
- **Save feedback**: Every successful create, edit, delete, sync or reset action
  must show a visible confirmation message, preferably a `SnackBar`, using
  localized text. Never leave the user guessing whether a save worked.

### Text Overflow & Visual Harmony (MANDATORY)

- **No overflow is acceptable**: Text must never exceed the bounds of cards/components or cause pixel overflow.
- **Use constraints**: Prefer `Flexible/Expanded`, and enforce `maxLines` + `overflow: TextOverflow.ellipsis` where appropriate.
- **Responsive typography**: Do not use excessively large or tiny text. Use Design System variants and keep hierarchy consistent.
- **Consistency across screens**: Keep spacing, headings, and component density consistent with the first screens already implemented.
- **Long-language safety**: Always consider that translations can be longer; design must still look clean in all supported locales.


## 4. Localization (l10n)

**NEVER** hardcode UI strings. All user-facing text must be in ARB files.

```dart
// ✅ CORRECT
AppText(context.l10n.helloWorld)

// ❌ WRONG
Text('Hello World')
```


### Multi-language From Day 1 (STRICT)

- Every feature must be implemented as **multi-language** from the start. It is not a “later task”.
- **Definition of Done (DoD)** for any UI change:
  - All user-visible strings are in ARB and wired through `context.l10n.*`.
  - Keys exist for **all supported locales** (at minimum `es` and `en`).
  - The UI is verified in **at least two locales** (one being Spanish).
  - Layout remains stable with longer translations (no clipping/overflow).


## 5. Code Quality Standards

### File Size Limits (STRICT)

- **Limit**: Files should not exceed **300 lines**.
- **Action**: If a file exceeds this limit, **IMMEDIATELY refactor**.
- **Strategy**: Extract widgets, move logic to BLoC/Domain, or create helper classes.

### Linting - Zero Tolerance


#### Baseline Ruleset (MANDATORY): `very_good_analysis`

To enforce consistent linting (including documentation discipline), the project must use `very_good_analysis`.

- Add dependency in `pubspec.yaml` (dev dependency):
  - `dev_dependencies:`
    - `very_good_analysis: ^10.0.0`
- If you intentionally want the newest **pre-release** (not recommended for production), check pub.dev versions.

- In `analysis_options.yaml`, include the ruleset:
  - `include: package:very_good_analysis/analysis_options.yaml`
- **Policy**:
  - `flutter analyze` must be clean before delivery.
  - Treat relevant warnings as blockers (especially documentation and unused/unsafe patterns).

> Note: Some documentation lints apply primarily to **public** APIs (e.g., `public_member_api_docs`). Private helpers still require comments when logic is non-trivial (see Documentation Standards).


- The project must pass `flutter analyze` with **zero** issues.
- No unused imports, variables, or unawaited futures.

### Performance

- Use `const` constructors whenever possible.
- Use `const` collections.

## 6. Tooling & Refactoring (MCP)

**Mandatory Usage of Dart MCP**:

- Use **Dart MCP (Model Context Protocol)** tools for all analysis and refactoring tasks to ensure safety and correctness.
- **Analyze First**: Run analysis before and after applying changes.
- **Automated Refactoring**: Rely on tools for renaming, extracting methods/widgets, and fixing implementation details.

## 7. Testing Requirements

- **Domain**: 100% coverage (Unit tests).
- **Application (BLoC)**: 80%+ coverage (Bloc tests).
- **Presentation**: Critical user flows (Widget/Integration tests).

## 8. File Organization & Naming

- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables**: `camelCase`
- **Imports**: Sorted alphabetically.

## 9. Error Handling Pattern

### BLoC Error States

Always define explicit error states:

```dart
sealed class FeatureState extends Equatable {}

final class FeatureError extends FeatureState {
  const FeatureError(this.message, {this.exception});
  final String message;
  final Exception? exception;

  @override
  List<Object?> get props => [message, exception];
}
```

### Try-Catch in BLoCs

Never swallow exceptions silently:

```dart
// ✅ CORRECT
Future<void> _onLoad(LoadEvent event, Emitter<State> emit) async {
  emit(const Loading());
  try {
    final data = await _repository.getData();
    emit(Loaded(data));
  } catch (e, stackTrace) {
    emit(FeatureError('Failed to load data: $e'));
    // Optionally log: _logger.error(e, stackTrace);
  }
}

// ❌ WRONG - Silent failure
try {
  await doSomething();
} catch (e) {
  // Empty catch block
}
```

## 10. Async/Await Best Practices

### Always await or explicitly ignore

```dart
// ✅ CORRECT - Awaited
await _repository.saveData(data);

// ✅ CORRECT - Fire and forget (explicit)
unawaited(_analytics.logEvent('action'));

// ❌ WRONG - Unawaited future (lint error)
_repository.saveData(data);  // Missing await!
```

### Stream Subscriptions

Always cancel subscriptions in `dispose()` or `close()`:

```dart
class FeatureBloc extends Bloc<Event, State> {
  StreamSubscription<Data>? _subscription;

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
```

## 11. Dependency Injection

### Provider/GetIt Pattern

Register dependencies at app initialization:

```dart
// ✅ CORRECT - Inject via constructor
class FeatureBloc extends Bloc<Event, State> {
  FeatureBloc({required IFeatureRepository repository})
      : _repository = repository,
        super(const Initial());

  final IFeatureRepository _repository;
}

// ❌ WRONG - Direct instantiation
class FeatureBloc extends Bloc<Event, State> {
  FeatureBloc() : super(const Initial()) {
    _repository = FeatureRepository(); // Hard dependency!
  }
}
```

## 12. Documentation Standards

## 13. Supabase Readiness (MANDATORY)

Every local feature must be designed so it can be migrated to the remote
Supabase project without rewriting the business flow.

- New local tables/entities must have a documented remote table equivalent in
  `Documentation/DATABASE.md` and `supabase/migrations`.
- Local records must keep stable local IDs and sync metadata:
  `remote_id`, `sync_status`, `sync_error`, `created_at`, `updated_at`,
  `synced_at`.
- Local-only temporary values are allowed only if they are centralized,
  documented, and mapped to their future Supabase field. They must not be
  scattered through UI or repositories.
- User-facing screens must never request Supabase IDs, UUIDs, table names,
  sync states, or foreign keys directly.
- Any new feature that creates or updates business data must enqueue a sync
  operation or explicitly document why it is local-only.
- Remote-required fields must be known before finishing the local module. If a
  value is not collected in V1, define a deterministic mapping/fallback before
  marking the module complete.
- Before starting Supabase remote migration, run the Supabase readiness audit
  and resolve all blocker items.

Definition of Done for any data-affecting feature:

- Local entity/table exists or is intentionally not persisted.
- Remote table/columns are documented.
- Sync payload includes enough data to create/update remotely.
- Audit behavior is defined for sensitive actions.
- Auth/restaurant ownership mapping is clear, even if Auth is still disabled.

## 14. SmooControl Project Rules (CRITICAL)

These rules are specific to `SmooControl`. They override generic assumptions.

### 14.1 Golden Rule For This Repository

- Do not make broad changes outside the requested scope.
- Before editing, run:

```powershell
git status --short
git log --oneline -5
```

- If the task is a POS UI change, do not touch auth, device initialization,
  Drift schema, Supabase migrations, Android manifest, app version, or build
  scripts unless the user explicitly asks for that.
- If the task is auth/device initialization, do not touch POS checkout, catalog
  sync, admin repositories, or visual widgets unless required by the bug.
- Never "clean up" unrelated files.
- Never change `applicationId`, package name, signing setup, or local database
  schema casually.
- If an APK was already distributed and a new APK must be installed over it,
  bump `pubspec.yaml` `versionCode` only after confirming the currently
  distributed `versionCode`.

### 14.2 Current Architecture

SmooControl has two operational modes:

- **Admin mode**: online-first / remote-first. Catalogs and administrative data
  must write directly to Supabase first.
- **POS mode**: offline-first. The tablet works from local Drift/SQLite and
  synchronizes operational transactions later.

Do not mix those rules.

### 14.3 Admin Mode Rules

Admin catalogs and administrative screens must be remote-only from the UI
perspective:

- products
- categories
- payment methods
- tables catalog fields
- modifiers catalog
- roles, permissions, users
- packaging rules/items/sales types
- exchange rates
- inventory purchases and packaging purchases
- sales admin views/actions
- expenses admin views/actions
- audit log views/actions
- business settings

For admin saves:

- Read from Supabase directly when entering the screen.
- Write/update/delete in Supabase directly.
- Refresh visible lists from Supabase after a successful save.
- Do not write Drift/local tables from admin screens.
- Do not enqueue admin changes in the sync queue as the primary path.
- Do not use `AdminDataRefreshService` from admin BLoCs/pages to refresh local
  cache.
- Do not tell the UI "guardado" if the remote write failed.
- Keep local repositories for POS and catalog sync only.

Admin create/edit forms must not expose technical identifiers:

- Do not show or request `id`, UUID, remote id, local id, sequence number or
  sync ids as editable fields.
- New records must let Supabase/RPC assign the technical id.
- If the business needs a visible consecutive, create a dedicated business
  number/code managed by Supabase, starting from `1` per restaurant when
  applicable.
- The UI may display that business number after creation, but must not let the
  user type it during normal creation.

### 14.4 POS Mode Rules

POS operational data is local-first:

- open tickets
- cart lines
- table operational state
- table temporary display name, for example `Mesa 1` shown as `JOSE`
- cash register sessions
- local expenses from POS
- sales created by POS
- POS modifier availability

POS sales are synchronized upward later. The remote side assigns/controls the
  invoice consecutive. Do not burn local invoice numbers before the sale is
  accepted.

POS sale synchronization must be FIFO and single-lane:

- `SyncQueueProcessor` is the source of truth for retry order.
- `syncOnSave` must never send a later sale while an older sale is still
  `pending`, `syncing` or `error`.
- If an older sale has an error, later sales must remain queued until the older
  error is fixed or explicitly retried successfully.
- Do not add direct background pushes that bypass `local_sync_queue`.
- A sale retry must be idempotent by stable local sale id, not by invoice text.

Local-only POS values must not be pushed upward unless explicitly requested.
Known local-only examples:

- `RestaurantTable.displayName` edited from POS.
- `ModifierOption.isAvailableInPos` toggled from POS.

Catalog pull from Supabase must preserve those local-only POS values.

### 14.5 Device Initialization And Login

The clean APK/tablet flow is:

1. App starts.
2. `AuthGate` asks `DeviceInitializationService.getStartupMode()`.
3. A clean Supabase-configured tablet must show `DeviceInitializationPage`.
4. After successful restore, local users/PINs and operational catalog exist.
5. POS users log in locally with email/PIN.

Do not modify this flow for UI work.

Do not touch these files unless the task is specifically auth/init related:

- `lib/features/auth/**`
- `lib/core/di/register_auth_dependencies.dart`
- `lib/core/database/app_database.dart`
- `lib/core/database/tables/**`
- `android/app/src/main/AndroidManifest.xml`
- `supabase/migrations/**`

If those files change unexpectedly during a POS UI task, stop and revert those
unrelated edits before building an APK.

### 14.6 POS Mobile Payment Shortcuts

The mobile POS quick payment row is:

```text
DOLAR | MAS OPCIONES | CORDOBA
```

Rules:

- Do not hardcode payment method IDs.
- Do not depend on visible names like `Dolar`, `Cordoba`, `Cash`, or
  `Efectivo`.
- Resolve shortcuts from catalog data:
  - active method
  - `isPaymentTarget == true`
  - `affectsCashRegister == true`
  - `currencyCode == USD` for DOLAR
  - `currencyCode == NIO` for CORDOBA
- Keep those methods inside their existing payment catalog hierarchy.
- Do not remove them from `Mas opciones`; shortcuts are only convenience
  buttons.
- Reuse the shared POS payment flow so validation, amount dialog, USD exchange
  rate, change calculation, and checkout remain identical.

### 14.7 POS Mobile Catalog/Detail Switch

The mobile POS uses the cart button as a strict two-state switch:

```text
detail mode:  order detail visible, product catalog hidden, categories visible
cart mode:    order detail hidden, product catalog visible, categories visible
```

Rules:

- The cart button and selecting a category may activate cart mode.
- Pressing the cart button while cart mode is active must return to detail
  mode.
- Categories remain visible in both modes.
- Do not reintroduce the old `Ocultar productos` strip on phone layout.
- Do not let product visibility be controlled by independent booleans that can
  drift from the active mobile mode.
- Use stable widget keys in tests for cart interactions because the icon changes
  by mode.
- The cart icon must communicate mode:
  - cart mode uses a cart icon and active premium color from `AppPalette` or
    `ColorScheme`.
  - detail mode uses a detail/receipt icon and a distinct premium color from
    `AppPalette` or `ColorScheme`.
- Do not hardcode colors with `Color(0x...)` or `Colors.*` in POS widgets.

### 14.8 POS Mobile Sales Type Selector

The compact `Mas opciones` dialog owns the sales type selector for phone POS.

Rules:

- `Comer aqui` is the default sales type when no order-specific type exists.
- Selecting `GO` / `Para llevar` must dispatch `PosSalesTypeSelected` and update
  `selectedSalesTypeId` for the active order.
- This selection is business-critical because checkout packaging consumption
  depends on the selected sales type.
- The compact selector must provide immediate visual feedback inside the modal
  (for example check/radio toggle state), even before the parent POS screen
  rebuilds.
- Do not implement it as plain ambiguous buttons.
- Add or keep tests that select `GO` through compact more options and assert
  the BLoC selected sales type changed.

### 14.9 KDS Scope

KDS is explicitly deferred to Version 2.

- Do not implement KDS tables, product KDS fields, routes, roles, permissions,
  Supabase migrations, realtime subscriptions, or UI in V1 unless the user
  explicitly reopens the scope.
- The documented V2 direction is remote-first KDS over Supabase.
- POS remains offline-first; if internet is down, KDS delivery is manual.
- Future KDS must use configurable stations, for example `Cocina` and
  `Mostrador/Baño Maria`, not hardcoded product-name rules.
- Future product routing should be modeled as:
  - `applies_to_kds`
  - `kds_station_id`
- Future roles should use permissions per station, not only role names.
- See `Documentation/PROJECT_TRACKING.md` and
  `Documentation/BUSINESS_RULES.md`.

### 14.10 Supabase Credentials

Never hardcode Supabase values in Dart, Android, web files, or tests.

Credentials are read from:

```text
Requerimiento/CredencialesSupabase.md
```

Expected keys:

```text
SMOO_SUPABASE_URL=
SMOO_SUPABASE_PUBLISHABLE_KEY=
SMOO_RESTAURANT_ID=
```

Build scripts inject them with `--dart-define`.

Use the scripts. Do not manually paste credentials into commands, source code,
or documentation.

If an APK shows `Supabase no esta configurado para inicializar este
dispositivo`, the first suspect is an APK built without these dart-defines.
Rebuild with `tool/build_android_release.ps1`.

### 14.11 APK Build Procedure

Before building any APK candidate, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\production_preflight.ps1
```

Build production APK only with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android_release.ps1
```

Never use this command for an APK that will be installed on a phone/tablet:

```powershell
flutter build apk --release
```

That raw command produces an APK without Supabase/restaurant dart-defines. It
will compile, but remote admin login and device initialization can fail.

Output:

```text
release/SmooControl-produccion.apk
release/SmooControl-produccion.buildinfo.txt
```

Mandatory APK validation:

```powershell
$aapt = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools" `
  -Recurse -Filter aapt.exe |
  Sort-Object FullName -Descending |
  Select-Object -First 1

& $aapt.FullName dump permissions release\SmooControl-produccion.apk
& $aapt.FullName dump badging release\SmooControl-produccion.apk |
  Select-String -Pattern "package:"
Get-Content release\SmooControl-produccion.buildinfo.txt
```

Must verify:

- `android.permission.INTERNET` exists.
- package name remains `com.smoocontrol.pos`.
- `versionCode` is greater than the APK already installed in production.
- `versionName` matches `pubspec.yaml`.
- build info says
  `InjectedDartDefines=SMOO_SUPABASE_URL,SMOO_SUPABASE_PUBLISHABLE_KEY,SMOO_RESTAURANT_ID`.
- build info says `SqliteNativeLibrary=PRESENTE`.
- APK contains `lib/arm64-v8a/libsqlite3.so` at minimum. Missing SQLite native
  libs can break POS local storage, sync, utilities, and any Drift-backed flow
  on Android.
- `Documentation/V1_RELEASE_CANDIDATE_CHECKLIST.md` has been executed for the
  candidate APK.
- `Documentation/APK_RELEASE_BUILD_PROCEDURE.md` was followed.

Never ask the user to uninstall the app if there may be unsynchronized POS
operations. Install updates over the existing APK.

### 14.12 Web Release Procedure

Build web release only with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1
```

This also builds/copies Drift web assets:

- `sqlite3.wasm`
- `drift_worker.js`

Operational server commands are documented in:

```text
comandos.md
```

### 14.13 Drift Database And Migrations

- Do not bump `schemaVersion` without a non-destructive migration.
- Do not delete or recreate local operational tables.
- Do not write migrations that lose pending POS sales, open tickets, cash
  sessions, expenses, or sync queue rows.
- Migration tests are required for every schema change.
- If a migration touches device initialization state, test clean install and
  update-over-existing-APK scenarios.

### 14.13.1 Supabase Remote Migrations

- If a requested improvement requires Supabase schema/RPC/permission changes,
  create the migration and apply it to the linked Supabase project in the same
  work session.
- Do not wait for the user to ask "haz la migracion" after implementing a
  feature that depends on new remote tables, columns, policies, permissions or
  RPCs.
- Before applying, verify the linked project and pending migration list with
  Supabase CLI.
- Apply pending migrations with the project scripts/CLI, not by pasting SQL in
  the dashboard unless the CLI is unavailable.
- After applying, report which migration files were pushed and whether the
  command succeeded.
- If the migration fails, stop and fix the SQL/RPC/policy issue before
  rebuilding or delivering an APK that depends on it.
- Never print or hardcode Supabase secrets while running migrations.

### 14.13.2 Supabase Remote Queries

- For ad-hoc remote data checks, use the linked Supabase CLI first:

```powershell
supabase db query "select now() as checked_at;" --linked
```

- Do not start with raw `psql` or custom Node/Postgres clients unless
  `supabase db query --linked` is unavailable.
- The direct host `db.<project-ref>.supabase.co` can resolve only IPv6 in this
  environment and may fail from Node/Windows. Treat that as an environment/DNS
  issue, not as proof that Supabase is down.
- Use `Documentation/SUPABASE_REMOTE_ACCESS.md` for the canonical commands to
  inspect sales, sale detail, recipe inventory movements, stock and POS
  devices.
- Never print database passwords, access tokens or secret keys in user-facing
  responses.
- Manual production `update`/`delete` statements must be preceded by a
  `select` preview and constrained by `restaurant_id` plus the smallest
  reliable business key, such as `id`, `pos_device_id`, date range or invoice.

### 14.14 Required Validation Before Delivery

For POS UI/payment changes, run at minimum:

```powershell
dart analyze lib\features\pos\presentation\widgets test\features\pos\presentation\widgets\pos_ready_view_test.dart
flutter test test\features\pos\presentation\widgets\pos_ready_view_test.dart test\features\pos\presentation\bloc\pos_bloc_test.dart
```

For auth/device initialization changes, run at minimum:

```powershell
dart analyze lib\features\auth lib\core\database test\features\auth test\core\database
flutter test test\features\auth\domain\services\device_initialization_service_test.dart test\core\database\app_database_test.dart
```

Before building any production APK after mixed changes, run both POS and auth
test groups.

### 14.15 Git Discipline

- Keep commits scoped.
- Commit POS UI changes separately from auth/database/build changes.
- Before commit, run:

```powershell
git diff --stat
git diff --name-status
```

- If a POS-only task shows diffs in auth/database/manifest/migrations, revert
  those unrelated files before commit.
- After commit and push, confirm:

```powershell
git status --short
git log --oneline -3
```


### Business Rules Register (MANDATORY)

Business rules must be documented in a human-readable and developer-friendly way, with examples.

- Maintain a single source of truth:
  - `Documentation/BUSINESS_RULES.md`
- For every feature/fix that changes behavior, update the register with:
  - **Rule name** (short)
  - **Description** (clear and explicit)
  - **Rationale** (why it exists)
  - **Examples** (inputs/outputs and UI examples)
  - **Edge cases** (what can go wrong, validations, limits)
  - **Related screens/flows** (links/paths)
  - **Data impact** (DB fields, API contracts, migrations)

Recommended format:

```md
## <Feature> / <Module>

### Rule: <Short name>
- Description:
- Rationale:
- Example(s):
- Edge cases:
- Data impact:
- Notes:
```
### Code Commenting Standard (STRICT)

- **All new or modified code must be understandable without reverse-engineering.**
- Add documentation for:
  - Every **class** and **public method** (`///` Dart doc comments).
  - Every **non-trivial method** (public or private): short comment describing intent (“what/why”, not “how”).
  - Complex blocks/algorithms: inline comments explaining the logic and assumptions.

**Enforcement**:
- Use `very_good_analysis` as the baseline lint ruleset.
- If analysis reports missing documentation for public APIs, documentation must be added immediately.


### Public API Documentation

Every public class, method, and property must have `///` doc comments:

```dart
/// Manages product catalog operations.
///
/// Provides CRUD operations for products including
/// filtering by category and search functionality.
class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  /// Creates a [CatalogBloc] with the given [repository].
  CatalogBloc({required IProductR
