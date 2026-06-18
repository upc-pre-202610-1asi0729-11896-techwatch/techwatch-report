# TechWatch — Especificación de Event Storming (corregida)

> Derivado de [ddd-design.md](ddd-design.md). Regla de oro: **cada sticky debe ser demostrable en código**.
> Cada evento naranja corresponde a un cambio de estado persistido (o evento de dominio publicado),
> cada comando azul corresponde a un `record` Command con su handler, y los dashboards/listas son
> read models (verde), nunca eventos.
>
> Colores estándar: 🟧 Domain Event · 🟦 Command · 🟨 Actor · 🟩 Read Model · 🟪 Policy · ⬜ External System

---

## 1. Big Picture Event Storming (sección 2.4)

Cinco columnas: **IAM**, **Profiles**, **Device Management**, **Analytics**, **Subscriptions**.

| Contexto | Actor | Domain Events (en orden) |
|---|---|---|
| IAM | User | User Registered · User Signed In |
| Profiles | System | Profile Created (automático al registrarse) |
| Profiles | User | Profile Updated · Preferences Updated |
| Device Management | User | Property Registered · Space Created · Device Added to Space · Device Updated · Device Deleted |
| Device Management | User/System | Simulation Session Started · Device Action Recorded · Usage Data Generated · Simulation Session Ended |
| Analytics | System | Metrics Calculated · Consumption Report Generated · High Consumption Alert Triggered |
| Analytics | User | Alert Marked As Read |
| Subscriptions | User | Subscription Created · Subscription Plan Changed · Subscription Cancelled · Subscription Renewed |
| Subscriptions | Payment Service (ext.) | Payment Processed |

Cambios vs versión actual:
- ❌ Eliminar **"Dashboard Updated"** (read model, no evento — no tiene implementación demostrable).
- ❌ Eliminar **"Subscription Plan Selected"** (acción de UI, no evento de dominio) y **"Subscription Updated"** (se reemplaza por los eventos específicos Created/Changed/Cancelled/Renewed).
- 🔄 **"Usage Data Generated" se mueve de Analytics a Device Management** (lo publica SimulationSession).
- 🔄 **"Session Started" (IAM) → "User Signed In"** (resultado del SignInCommand; no se persiste sesión por usar JWT).
- 🔄 **"Profile Created"** pasa de actor User a actor **System** (se crea automáticamente vía evento).
- ➕ Agregar simulación en DM, Cancelled/Renewed en Subscriptions (US09/US10), Alert Marked As Read en Analytics.
- 🔄 Renombrar columnas: Payment → **Subscriptions**, Profile → **Profiles**.

---

## 2. Design-Level Event Storming (sección 4.6.1)

Formato por flujo: 🟨 Actor → 🟩 Read Model → 🟦 Command → Aggregate → 🟧 Event (→ 🟪 Policy).

### IAM

| Flujo | Actor | Read Model | Command | Aggregate | Event | Policy |
|---|---|---|---|---|---|---|
| Registro | User | Sign-up Form | Sign Up | User | User Registered | Cuando un usuario se registra, el sistema crea automáticamente su perfil (→ Profiles) |
| Inicio de sesión | User | Sign-in Form | Sign In | User | User Signed In | — (el sistema emite un token JWT como resultado) |

### Profiles

| Flujo | Actor | Read Model | Command | Aggregate | Event | Policy |
|---|---|---|---|---|---|---|
| Creación automática | System | — | Create Profile | Profile | Profile Created | Disparado por la policy de User Registered |
| Actualizar perfil | User | Profile Detail | Update Profile | Profile | Profile Updated | — |
| Actualizar preferencias | User | Preferences View | Update Preferences | Profile | Preferences Updated | — |

### Device Management

| Flujo | Actor | Read Model | Command | Aggregate | Event | Policy |
|---|---|---|---|---|---|---|
| Registrar inmueble | User | User's Properties List | Register Property | Property | Property Registered | — |
| Crear espacio | User | Property View with Spaces | Create Space | Property | Space Created | — |
| Agregar dispositivo | User | Available Spaces List | Add Device to Space | Device | Device Added to Space | Antes de agregar, el sistema valida el límite de dispositivos del plan del usuario (ACL → Subscriptions) |
| Editar dispositivo | User | Selected Device Detail | Edit Device | Device | Device Updated | — |
| Eliminar dispositivo | User | Devices List | Delete Device | Device | Device Deleted | — |
| Iniciar simulación | User | Property Devices View (Remote App) | Start Simulation Session | SimulationSession | Simulation Session Started | — |
| Accionar dispositivo | User | Device Control View (Remote App) | Record Device Action | SimulationSession | Device Action Recorded · Usage Data Generated | Cuando se acciona un dispositivo en sesión activa, el sistema genera datos de uso y publica el evento (→ Analytics) |
| Finalizar simulación | User | Active Session View | End Simulation Session | SimulationSession | Simulation Session Ended | — |

### Analytics

| Flujo | Actor | Read Model | Command | Aggregate | Event | Policy |
|---|---|---|---|---|---|---|
| Calcular métricas | System | Generated Usage Data | Calculate Metrics | ConsumptionMetric | Metrics Calculated | Cuando se generan datos de uso (evento de DM), el sistema calcula métricas automáticamente |
| Generar reporte (on-demand) | User | Period Selector | Generate Consumption Report | ConsumptionReport | Consumption Report Generated | — |
| Generar reporte (automático) | System | Session Usage Summary | Generate Consumption Report | ConsumptionReport | Consumption Report Generated | Cuando finaliza una sesión de simulación, el sistema genera un reporte del período |
| Disparar alerta | System | Current Metrics vs Threshold | Trigger Consumption Alert | ConsumptionAlert | High Consumption Alert Triggered | Cuando una métrica supera el umbral definido, el sistema dispara una alerta |
| Marcar alerta leída | User | Alerts List | Mark Alert As Read | ConsumptionAlert | Alert Marked As Read | — |

Cambio clave: el flujo "Generate Usage Data" desaparece de Analytics (ahora es parte de "Accionar dispositivo" en DM)
y el flujo "Update Dashboard" se elimina: el dashboard es el read model "Dashboard Summary" alimentado por
`GetDashboardSummaryByUserIdQuery`, no un evento.

### Subscriptions

| Flujo | Actor | Read Model | Command | Aggregate | Event | Policy |
|---|---|---|---|---|---|---|
| Suscribirse a un plan | User | Available Plans List | Create Subscription | Subscription | Subscription Created | Cuando se crea una suscripción de pago, el sistema solicita el procesamiento del pago al servicio externo |
| Procesar pago | Payment Service (ext.) | Plan Total & Payment Data | Process Payment | Payment | Payment Processed | Cuando el pago se procesa con éxito, el sistema activa la suscripción |
| Cambiar de plan | User | Current Plan & Available Plans | Change Subscription Plan | Subscription | Subscription Plan Changed | — |
| Cancelar suscripción | User | Active Subscription Detail | Cancel Subscription | Subscription | Subscription Cancelled | — |
| Renovar suscripción | User | Subscription Near Expiry | Renew Subscription | Subscription | Subscription Renewed | — |

---

## 3. Trazabilidad: evento → comando → implementación

Tabla de respuesta directa a "muéstrame la implementación de este comando/evento".

| Domain Event | Command (record) | Handler | Endpoint REST |
|---|---|---|---|
| User Registered | `SignUpCommand` | `UserCommandServiceImpl.handle(SignUpCommand)` + publica `UserRegisteredEvent` | `POST /api/v1/authentication/sign-up` |
| User Signed In | `SignInCommand` | `UserCommandServiceImpl.handle(SignInCommand)` → JWT | `POST /api/v1/authentication/sign-in` |
| Profile Created | `CreateProfileCommand` | `ProfileCommandServiceImpl.handle(...)` (invocado por `UserRegisteredEventHandler` vía `ProfilesContextFacade`) | `POST /api/v1/profiles` (también directo) |
| Profile Updated | `UpdateProfileCommand` | `ProfileCommandServiceImpl.handle(...)` | `PUT /api/v1/profiles/{id}` |
| Preferences Updated | `UpdatePreferencesCommand` | `ProfileCommandServiceImpl.handle(...)` | `PUT /api/v1/profiles/{id}/preferences` |
| Property Registered | `CreatePropertyCommand` | `PropertyCommandServiceImpl.handle(...)` | `POST /api/v1/properties` |
| Space Created | `CreateSpaceCommand` | `PropertyCommandServiceImpl.handle(...)` | `POST /api/v1/properties/{id}/spaces` |
| Device Added to Space | `AddDeviceToSpaceCommand` | `DeviceCommandServiceImpl.handle(...)` (valida límite vía `ExternalSubscriptionService`) | `POST /api/v1/devices` |
| Device Updated | `EditDeviceCommand` | `DeviceCommandServiceImpl.handle(...)` | `PUT /api/v1/devices/{id}` |
| Device Deleted | `DeleteDeviceCommand` | `DeviceCommandServiceImpl.handle(...)` | `DELETE /api/v1/devices/{id}` |
| Simulation Session Started | `StartSimulationSessionCommand` | `SimulationSessionCommandServiceImpl.handle(...)` | `POST /api/v1/simulation-sessions` |
| Device Action Recorded / Usage Data Generated | `RecordDeviceActionCommand` | `SimulationSessionCommandServiceImpl.handle(...)` + publica `UsageDataGeneratedEvent` | `POST /api/v1/simulation-sessions/{id}/actions` |
| Simulation Session Ended | `EndSimulationSessionCommand` | `SimulationSessionCommandServiceImpl.handle(...)` | `POST /api/v1/simulation-sessions/{id}/end` |
| Metrics Calculated | `CalculateMetricsCommand` | `AnalyticsCommandServiceImpl.handle(...)` (invocado por `UsageDataGeneratedEventHandler`) | — (interno, consultable en `GET /api/v1/metrics`) |
| Consumption Report Generated | `GenerateConsumptionReportCommand` | `AnalyticsCommandServiceImpl.handle(...)` | `POST /api/v1/reports` |
| High Consumption Alert Triggered | `TriggerConsumptionAlertCommand` | `AnalyticsCommandServiceImpl.handle(...)` (policy de umbral en el event handler) | — (interno, consultable en `GET /api/v1/alerts`) |
| Alert Marked As Read | `MarkAlertAsReadCommand` | `AnalyticsCommandServiceImpl.handle(...)` | `PUT /api/v1/alerts/{id}/read` |
| Subscription Created | `CreateSubscriptionCommand` | `SubscriptionCommandServiceImpl.handle(...)` | `POST /api/v1/subscriptions` |
| Payment Processed | `ProcessPaymentCommand` | `SubscriptionCommandServiceImpl.handle(...)` + `ExternalPaymentService` | interno al flujo de suscripción |
| Subscription Plan Changed | `ChangeSubscriptionPlanCommand` | `SubscriptionCommandServiceImpl.handle(...)` | `PUT /api/v1/subscriptions/{id}/plan` |
| Subscription Cancelled | `CancelSubscriptionCommand` | `SubscriptionCommandServiceImpl.handle(...)` | `PUT /api/v1/subscriptions/{id}/cancel` |
| Subscription Renewed | `RenewSubscriptionCommand` | `SubscriptionCommandServiceImpl.handle(...)` | `PUT /api/v1/subscriptions/{id}/renew` |

> El read model **Dashboard Summary** se implementa con `GetDashboardSummaryByUserIdQuery` →
> `AnalyticsQueryServiceImpl` → `GET /api/v1/dashboard` (por eso no es un evento).
