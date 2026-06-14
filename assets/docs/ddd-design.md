# TechWatch — Diseño DDD Canónico

> **Fuente de verdad del diseño.** Todos los artefactos (diagramas de clases PlantUML, ERDs de Vertabelo,
> workspace de Structurizr, código del backend y secciones 2.5 / 4.6 / 4.7 / 4.8 del report) deben
> mantenerse consistentes con este documento. Patrón de referencia: `learning-center-platform`.
>
> Última actualización: 2026-06-12

## 1. Decisiones de diseño

| # | Decisión | Justificación |
|---|----------|---------------|
| D1 | Jerarquía del dominio: `Property` → `Space` → `Device` (se descarta `Home`/`HomeType`) | Coincide con el Ubiquitous Language (2.5) y los ERDs; `Space` es necesario para US15/US16 y la vista por ambientes |
| D2 | El contexto de pagos se llama **Subscriptions** (`Payment` es un aggregate dentro de él) | El nombre del contexto debe reflejar su responsabilidad principal (planes y suscripciones), no una de sus entidades |
| D3 | El contexto **Simulation** de los ERDs se fusiona dentro de **Device Management** | La simulación es un caso de uso sobre los devices; evita un sexto contexto con poca entidad propia |
| D4 | **IAM propio con JWT + Spring Security** (se elimina el "Authentication Provider" externo de los C4) | Coincide con TS06/TS07 del backlog y con el patrón del proyecto de referencia |
| D5 | Solo los **Aggregate Roots** tienen repositorio | Regla DDD; corrige los repositorios de `Device`, `Payment`, `UserCredential` y `UserPreference` del diseño anterior |
| D6 | `UserCredential` se fusiona en `User` (IAM); `UserPreference` se fusiona en `Profile` como Value Object | Entidades de 2-3 campos sin ciclo de vida propio no justifican aggregate ni repositorio |
| D7 | IDs internos como `Long`; Value Objects de identidad **solo para referencias cross-context** (`UserId`, `PropertyId`, `DeviceId`) | Patrón del proyecto de referencia (`ProfileId`, `AcmeStudentRecordId`); evita sobre-ingeniería |
| D8 | `createdAt`/`updatedAt` **no son Value Objects**: son auditoría en infraestructura (`AuditableAbstractPersistenceEntity`) | El modelo de dominio no modela preocupaciones de persistencia |
| D9 | Aplicación con **CQRS ligero**: `XCommandService` / `XQueryService` + Commands y Queries como `record` con validación en constructor compacto | Patrón del proyecto de referencia |
| D10 | Integración entre contextos vía **ACL facades** y **eventos de dominio**, nunca imports directos del modelo ajeno | Patrón del proyecto de referencia (`ProfilesContextFacade`) |
| D11 | Base de datos **MySQL**, naming `snake_case` con tablas pluralizadas (naming strategy compartida) | Decisión del equipo; igual que el proyecto de referencia |
| D12 | Contenedores frontend: Landing Page, **Web Application** (gestión + dashboard) y **Remote Control App** (simulación móvil), ambas Angular | La Remote Control App es parte del alcance (control remoto / simulación de dispositivos) |

## 2. Arquitectura por capas (idéntica en cada bounded context)

```
<context>/
├── domain/
│   ├── model/
│   │   ├── aggregates/      // extienden AbstractDomainAggregateRoot
│   │   ├── entities/        // entidades internas del aggregate
│   │   ├── valueobjects/    // records con validación
│   │   ├── commands/        // records con validación
│   │   ├── queries/         // records
│   │   └── events/          // eventos de dominio
│   ├── exceptions/
│   └── repositories/        // puertos (interfaces), solo para roots
├── application/
│   ├── commandservices/     // interfaces XCommandService
│   ├── queryservices/       // interfaces XQueryService
│   ├── acl/                 // implementación del facade propio (si expone)
│   └── internal/
│       ├── commandservices/ // impl con Result<T, ApplicationError>
│       ├── queryservices/
│       ├── eventhandlers/
│       └── outboundservices/acl/   // External<X>Service hacia otros contextos
├── infrastructure/persistence/jpa/
│   ├── entities/            // XPersistenceEntity (JPA)
│   ├── embeddables/
│   ├── converters/
│   ├── assemblers/          // dominio ⇄ persistencia
│   ├── repositories/        // XPersistenceRepository (Spring Data)
│   └── adapters/            // XRepositoryImpl (implementa el puerto)
└── interfaces/
    ├── rest/                // controllers + resources/ + transform/
    ├── acl/                 // interfaz del facade que expone el contexto
    └── events/              // integration events (si aplica)
```

Paquete base: `com.techwatch.techwatchbackend`. Contextos: `iam`, `profiles`, `devices`, `analytics`, `subscriptions`, `shared`.

## 3. Bounded Contexts

### 3.1 IAM

| Elemento | Definición |
|---|---|
| Aggregate Root | `User` — `id: Long`, `email: EmailAddress`, `passwordHash: String`, `role: Role` |
| Value Objects | `EmailAddress` (record, valida formato), `Role` (enum: `ROLE_USER`, `ROLE_ADMIN`) |
| Commands | `SignUpCommand(email, password)`, `SignInCommand(email, password)` |
| Queries | `GetUserByIdQuery`, `GetUserByEmailQuery` |
| Eventos | `UserRegisteredEvent` (dispara creación de Profile vía handler/ACL) |
| Repositorio | `UserRepository` |
| Infraestructura extra | `TokenService` (JWT), `HashingService` (BCrypt), `AuthorizationRequestFilter` (Spring Security) |
| Expone ACL | `IamContextFacade`: `fetchUserIdByEmail(email)`, `fetchUserEmailById(userId)` |
| Endpoints | `POST /api/v1/authentication/sign-up`, `POST /api/v1/authentication/sign-in`, `GET /api/v1/users/{userId}` |

Notas: el password viaja como `String` en el command y se hashea en el command service. No existe entidad `UserCredential` ni VO `PasswordHash`/`AuthToken` (D6); el token es un artefacto de interfaz, no estado del dominio. La recuperación de contraseña (US03/TS08) se modela como command `ResetPasswordCommand` cuando se implemente.

### 3.2 Profiles

| Elemento | Definición |
|---|---|
| Aggregate Root | `Profile` — `id: Long`, `userId: UserId`, `fullName: PersonName`, `phoneNumber: String`, `profileImageUrl: String`, `preferences: Preferences` |
| Value Objects | `UserId` (cross-context), `PersonName(firstName, lastName)`, `Preferences(language, theme, notificationsEnabled)` |
| Commands | `CreateProfileCommand`, `UpdateProfileCommand`, `UpdatePreferencesCommand` |
| Queries | `GetProfileByIdQuery`, `GetProfileByUserIdQuery` |
| Repositorio | `ProfileRepository` |
| Expone ACL | `ProfilesContextFacade`: `createProfile(...)`, `fetchProfileIdByUserId(userId)` |
| Endpoints | `POST /api/v1/profiles`, `GET /api/v1/profiles/{profileId}`, `PUT /api/v1/profiles/{profileId}`, `PUT /api/v1/profiles/{profileId}/preferences` |

Notas: `UserPreference` deja de ser entidad con repositorio (D6) y pasa a ser el VO `Preferences` embebido (tabla `user_profiles`, columnas embebidas).

### 3.3 Device Management (incluye Simulación)

| Elemento | Definición |
|---|---|
| Aggregate Roots | `Property`, `Device`, `SimulationSession` |
| `Property` | `id: Long`, `userId: UserId`, `name`, `address`, `type: PropertyType`, `spaces: List<Space>` — métodos `addSpace`, `updateInformation` |
| `Space` (entidad interna de Property) | `id: Long`, `name`, `description` — sin repositorio propio |
| `Device` | `id: Long`, `spaceId: SpaceId`, `name`, `brand`, `model`, `type: DeviceType`, `status: DeviceStatus`, `powerWatts: PowerWatts` — métodos `turnOn`, `turnOff`, `updateInformation` |
| `SimulationSession` | `id: Long`, `userId: UserId`, `propertyId: PropertyId`, `status: SessionStatus`, `startedAt`, `endedAt`, `actions: List<DeviceAction>`, `usageData: List<UsageDataRecord>` — métodos `start`, `end`, `recordAction` |
| Entidades internas | `DeviceAction(deviceId, actionType, parameterName, parameterValue, executedAt)`, `UsageDataRecord(deviceId, consumptionValue, unit, recordedAt)` dentro de `SimulationSession` |
| Value Objects | `UserId`, `PropertyId`, `SpaceId`, `DeviceId` (cross-context/cross-aggregate), `PowerWatts`, enums `PropertyType(HOUSE, APARTMENT)`, `DeviceType(LIGHT, THERMOSTAT, CAMERA, SMART_PLUG, AIR_CONDITIONER, DOOR_LOCK)`, `DeviceStatus(ON, OFF)`, `SessionStatus(ACTIVE, ENDED)` |
| Commands | `CreatePropertyCommand`, `UpdatePropertyCommand`, `DeletePropertyCommand`, `CreateSpaceCommand`, `AddDeviceToSpaceCommand`, `EditDeviceCommand`, `DeleteDeviceCommand`, `StartSimulationSessionCommand`, `RecordDeviceActionCommand`, `EndSimulationSessionCommand` |
| Queries | `GetPropertiesByUserIdQuery`, `GetPropertyByIdQuery`, `GetDevicesBySpaceIdQuery`, `GetDevicesByPropertyIdQuery`, `GetDeviceByIdQuery`, `GetActiveSimulationSessionByUserIdQuery` |
| Eventos | `UsageDataGeneratedEvent` (lo consume Analytics), `DeviceStatusChangedEvent` |
| Repositorios | `PropertyRepository`, `DeviceRepository`, `SimulationSessionRepository` |
| Consume ACL | Subscriptions (`fetchMaxDevicesForUser`) para validar el límite de devices del plan al crear un device |
| Endpoints | `/api/v1/properties` (+`/{id}/spaces`), `/api/v1/devices`, `/api/v1/simulation-sessions` |

Notas: `Device` sube a aggregate root (D5) porque se consulta y modifica de forma independiente (TS11/TS12) — referencia a `Space` por `SpaceId`, no por composición. La relación `Property 1—* Space` sí es composición dentro del aggregate.

### 3.4 Analytics

| Elemento | Definición |
|---|---|
| Aggregate Roots | `ConsumptionMetric`, `ConsumptionReport`, `ConsumptionAlert` |
| `ConsumptionMetric` | `id: Long`, `propertyId: PropertyId`, `deviceId: DeviceId` (nullable), `metricType: MetricType`, `value: EnergyConsumption`, `period: ConsumptionPeriod`, `calculatedAt` |
| `ConsumptionReport` | `id: Long`, `userId: UserId`, `propertyId: PropertyId`, `period: ConsumptionPeriod`, `totalConsumption: EnergyConsumption`, `generatedAt`, `items: List<ReportItem>` |
| `ReportItem` (entidad interna) | `deviceId: DeviceId`, `deviceName`, `consumption: EnergyConsumption`, `usageFrequency` |
| `ConsumptionAlert` | `id: Long`, `userId: UserId`, `propertyId: PropertyId`, `deviceId: DeviceId`, `severity: AlertSeverity`, `message`, `threshold`, `currentValue`, `isRead`, `triggeredAt` — método `markAsRead` |
| Value Objects | `EnergyConsumption(value, unit)`, `ConsumptionPeriod(startDate, endDate)`, `MetricType` (enum), `AlertSeverity(LOW, MEDIUM, HIGH)`, cross-context: `UserId`, `PropertyId`, `DeviceId` |
| Commands | `CalculateMetricsCommand`, `GenerateConsumptionReportCommand`, `TriggerConsumptionAlertCommand`, `MarkAlertAsReadCommand` |
| Queries | `GetMetricsByPropertyIdQuery`, `GetDashboardSummaryByUserIdQuery`, `GetReportsByPropertyIdQuery`, `GetReportByIdQuery`, `GetAlertsByUserIdQuery` |
| Event handlers | `UsageDataGeneratedEventHandler` → calcula métricas y evalúa umbrales de alerta |
| Repositorios | `ConsumptionMetricRepository`, `ConsumptionReportRepository`, `ConsumptionAlertRepository` |
| Endpoints | `/api/v1/metrics`, `/api/v1/dashboard`, `/api/v1/reports`, `/api/v1/alerts` |

### 3.5 Subscriptions

| Elemento | Definición |
|---|---|
| Aggregate Roots | `Plan`, `Subscription`, `Payment` |
| `Plan` | `id: Long`, `name`, `type: PlanType`, `price: Money`, `billingCycle: BillingCycle`, `maxDevices`, `hasAdvancedMetrics`, `hasCustomReports`, `hasAlerts`, `hasUnlimitedHistory`, `isActive` |
| `Subscription` | `id: Long`, `userId: UserId`, `planId: PlanId`, `status: SubscriptionStatus`, `startDate`, `endDate`, `autoRenew` — métodos `activate`, `cancel`, `renew`, `changePlan` |
| `Payment` | `id: Long`, `subscriptionId: SubscriptionId`, `amount: Money`, `status: PaymentStatus`, `externalPaymentId`, `processedAt` — método `confirm` |
| Value Objects | `Money(amount, currency)`, `PlanId`, `SubscriptionId`, `UserId`, enums `PlanType(FREE, PREMIUM)`, `BillingCycle(MONTHLY, YEARLY)`, `SubscriptionStatus(ACTIVE, CANCELLED, EXPIRED)`, `PaymentStatus(PENDING, COMPLETED, FAILED)` |
| Commands | `CreateSubscriptionCommand`, `ChangeSubscriptionPlanCommand`, `CancelSubscriptionCommand`, `RenewSubscriptionCommand`, `ProcessPaymentCommand` |
| Queries | `GetAllPlansQuery`, `GetActiveSubscriptionByUserIdQuery`, `GetPaymentsBySubscriptionIdQuery` |
| Repositorios | `PlanRepository`, `SubscriptionRepository`, `PaymentRepository` |
| Infraestructura extra | `ExternalPaymentService` (adapter hacia el Payment Service externo, ej. Stripe — simulado) |
| Expone ACL | `SubscriptionsContextFacade`: `fetchMaxDevicesForUser(userId)`, `hasFeature(userId, feature)` |
| Endpoints | `/api/v1/plans`, `/api/v1/subscriptions`, `/api/v1/subscriptions/{id}/payments` |

Notas: `Payment` sube a aggregate root (D5) porque las transacciones tienen ciclo de vida independiente y se consultan por separado. `Plan` reemplaza al enum `PlanType` como contenedor de las características del freemium (coincide con la tabla `plans` del ERD).

### 3.6 Shared

`shared/domain/model/aggregates/AbstractDomainAggregateRoot`, `shared/application/result/{Result, ApplicationError}`, `shared/infrastructure/persistence/jpa/entities/AuditableAbstractPersistenceEntity` (auditoría `created_at`/`updated_at`), naming strategy snake_case pluralizado, `shared/infrastructure/documentation/openapi` (Swagger), `shared/interfaces/rest/{GlobalExceptionHandler, ErrorResource, MessageResource, ResponseEntityAssembler}`.

## 4. Mapa de contexto (integraciones)

| Origen | Destino | Mecanismo | Propósito |
|---|---|---|---|
| IAM | Profiles | `UserRegisteredEvent` + `ProfilesContextFacade` | Crear el perfil al registrarse (US01) |
| Device Management | Subscriptions | `SubscriptionsContextFacade` (outbound ACL) | Validar `maxDevices` del plan antes de crear un device |
| Device Management | Analytics | `UsageDataGeneratedEvent` (evento) | Calcular métricas y disparar alertas a partir de la simulación |
| Subscriptions | Payment Service (externo) | `ExternalPaymentService` (adapter HTTP) | Procesar pagos |

Las FKs físicas entre esquemas (`users_id`, `properties_id`, `devices_id` en tablas de Analytics) son aceptables por ser una BD única, pero el **código** solo cruza contextos por ACL/eventos (D10).

## 5. Modelo de datos (MySQL, snake_case, tablas pluralizadas)

| Contexto | Tablas |
|---|---|
| IAM | `users (id, email UK, password_hash, role, created_at, updated_at)` |
| Profiles | `profiles (id, user_id FK→users, first_name, last_name, phone_number, profile_image_url, language, theme, notifications_enabled, created_at, updated_at)` |
| Device Management | `properties (id, user_id, name, address, property_type, ...)`, `spaces (id, property_id, name, description, ...)`, `devices (id, space_id, name, brand, model, device_type, status, power_watts, ...)`, `simulation_sessions (id, user_id, property_id, status, started_at, ended_at, ...)`, `device_actions (id, simulation_session_id, device_id, action_type, parameter_name, parameter_value, executed_at)`, `usage_data (id, simulation_session_id, device_id, consumption_value, unit, recorded_at)` |
| Analytics | `metrics (id, property_id, device_id, metric_type, value, unit, period_start, period_end, calculated_at)`, `consumption_reports (id, user_id, property_id, period_start, period_end, total_consumption, is_automatic, generated_at)`, `report_items (id, consumption_report_id, device_id, device_name, total_consumption, unit, usage_frequency)`, `consumption_alerts (id, user_id, property_id, device_id, severity, message, threshold, current_value, is_read, triggered_at)` |
| Subscriptions | `plans (id, name, plan_type, price_amount, price_currency, billing_cycle, max_devices, has_advanced_metrics, has_custom_reports, has_alerts, has_unlimited_history, is_active, ...)`, `subscriptions (id, user_id, plan_id, status, start_date, end_date, auto_renew, ...)`, `payments (id, subscription_id, amount_value, amount_currency, status, external_payment_id, processed_at)` |

Cambios vs ERDs actuales: `users` se documenta en IAM (no en Device Management); `full_name` de `users` pasa a Profiles como `first_name`/`last_name`; `devices` gana `power_watts` y referencia solo `space_id` (se elimina la FK redundante a `properties`); `user_profiles` se renombra a `profiles`; los ERDs de IAM y Profile deben crearse (hoy el report repite la imagen de Simulation).

## 6. Artefactos a actualizar (checklist)

- [ ] 2.5 Ubiquitous Language: agregar `Plan`, `Simulation Session`, `Device Action`; alinear `Device Status` (ON/OFF)
- [ ] 4.6 C4 (Structurizr `workspace.dsl`): IAM y Profiles como BCs, sin Auth Provider externo, MySQL, Simulation fusionado en DM, Remote Control App documentada en el texto
- [ ] 4.7 Diagramas de clases PlantUML (5, como enlaces): regenerar según este documento
- [ ] 4.8 ERDs Vertabelo (5): corregir DM/Analytics/Subscriptions, crear IAM y Profiles, MySQL
- [ ] Texto de 4.6.x, 4.7.1, 4.8.1 y arreglar el enlace duplicado de `chapter-4-8-1-img4.png`
