# TechWatch — Especificación de ERDs (Vertabelo / MySQL)

> Derivado de [ddd-design.md](ddd-design.md) (sección 5). Un diagrama por bounded context, 5 en total.
> Convenciones: motor MySQL, nombres `snake_case`, tablas pluralizadas, PK `id BIGINT` autoincremental,
> columnas FK con patrón `<singular>_id` (ej. `user_id`, no `users_id` como en los ERDs anteriores).
> Todas las tablas con datos mutables llevan `created_at TIMESTAMP NOT NULL` y `updated_at TIMESTAMP NOT NULL`.
>
> Las tablas de otros contextos se dibujan como **referencia externa** (recuadro punteado, como ya hiciste
> con "Device Management" dentro del ERD de Analytics). Solo la tabla `users` y las que se indiquen.

---

## ERD 1 — IAM

Tablas propias: `users`.

### users
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| email | VARCHAR(255) | NOT NULL, UNIQUE |
| password_hash | VARCHAR(255) | NOT NULL |
| role | VARCHAR(50) | NOT NULL (valores: ROLE_USER, ROLE_ADMIN) |
| created_at | TIMESTAMP | NOT NULL |
| updated_at | TIMESTAMP | NOT NULL |

Cambios vs versión anterior: `users` ya no lleva `full_name` (se movió a Profiles como `first_name`/`last_name`); desaparece la tabla `user_credentials` (las credenciales viven en `users.password_hash`). No hay tabla de tokens: el JWT no se persiste.

---

## ERD 2 — Profiles

Tablas propias: `profiles`. Referencia externa: `users` (IAM).

### profiles
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| user_id | BIGINT | NOT NULL, UNIQUE, FK → users.id |
| first_name | VARCHAR(255) | NOT NULL |
| last_name | VARCHAR(255) | NOT NULL |
| phone_number | VARCHAR(50) | NULL |
| profile_image_url | VARCHAR(500) | NULL |
| language | VARCHAR(10) | NOT NULL (ej. 'es', 'en') |
| theme | VARCHAR(20) | NOT NULL (ej. 'light', 'dark') |
| notifications_enabled | BOOLEAN | NOT NULL |
| created_at | TIMESTAMP | NOT NULL |
| updated_at | TIMESTAMP | NOT NULL |

Cambios vs versión anterior: la tabla se llama `profiles` (antes `user_profiles`); desaparece la tabla de preferencias separada — `language`, `theme` y `notifications_enabled` son columnas embebidas del VO `Preferences`. Relación 1:1 con `users` (por eso `user_id` es UNIQUE).

---

## ERD 3 — Device Management (incluye simulación)

Tablas propias: `properties`, `spaces`, `devices`, `simulation_sessions`, `device_actions`, `usage_data`.
Referencia externa: `users` (IAM).

### properties
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| user_id | BIGINT | NOT NULL, FK → users.id |
| name | VARCHAR(255) | NOT NULL |
| address | VARCHAR(500) | NULL |
| property_type | VARCHAR(50) | NOT NULL (HOUSE, APARTMENT) |
| created_at / updated_at | TIMESTAMP | NOT NULL |

### spaces
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| property_id | BIGINT | NOT NULL, FK → properties.id |
| name | VARCHAR(255) | NOT NULL |
| description | VARCHAR(500) | NULL |
| created_at / updated_at | TIMESTAMP | NOT NULL |

### devices
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| space_id | BIGINT | NOT NULL, FK → spaces.id |
| name | VARCHAR(255) | NOT NULL |
| brand | VARCHAR(255) | NULL |
| model | VARCHAR(255) | NULL |
| device_type | VARCHAR(50) | NOT NULL (LIGHT, THERMOSTAT, CAMERA, SMART_PLUG, AIR_CONDITIONER, DOOR_LOCK) |
| status | VARCHAR(20) | NOT NULL (ON, OFF) |
| power_watts | DECIMAL(10,2) | NOT NULL |
| created_at / updated_at | TIMESTAMP | NOT NULL |

Cambios vs versión anterior: se elimina la FK redundante `properties_id` (el inmueble se obtiene vía `space_id → property_id`); se agrega `power_watts`.

### simulation_sessions
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| user_id | BIGINT | NOT NULL, FK → users.id |
| property_id | BIGINT | NOT NULL, FK → properties.id |
| status | VARCHAR(20) | NOT NULL (ACTIVE, ENDED) |
| started_at | TIMESTAMP | NOT NULL |
| ended_at | TIMESTAMP | NULL |
| created_at / updated_at | TIMESTAMP | NOT NULL |

### device_actions
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| simulation_session_id | BIGINT | NOT NULL, FK → simulation_sessions.id |
| device_id | BIGINT | NOT NULL, FK → devices.id |
| action_type | VARCHAR(100) | NOT NULL |
| parameter_name | VARCHAR(255) | NULL |
| parameter_value | VARCHAR(255) | NULL |
| executed_at | TIMESTAMP | NOT NULL |

### usage_data
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| simulation_session_id | BIGINT | NOT NULL, FK → simulation_sessions.id |
| device_id | BIGINT | NOT NULL, FK → devices.id |
| consumption_value | DECIMAL(10,2) | NOT NULL |
| unit | VARCHAR(50) | NOT NULL (ej. 'kWh') |
| recorded_at | TIMESTAMP | NOT NULL |

---

## ERD 4 — Analytics

Tablas propias: `metrics`, `consumption_reports`, `report_items`, `consumption_alerts`.
Referencias externas: `users` (IAM), `properties` y `devices` (Device Management).

### metrics
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| property_id | BIGINT | NOT NULL, FK → properties.id |
| device_id | BIGINT | NULL, FK → devices.id (NULL = métrica a nivel de inmueble) |
| metric_type | VARCHAR(50) | NOT NULL (ENERGY_CONSUMPTION, USAGE_TIME, USAGE_FREQUENCY) |
| value | DECIMAL(10,2) | NOT NULL |
| unit | VARCHAR(50) | NOT NULL |
| period_start | DATE | NOT NULL |
| period_end | DATE | NOT NULL |
| calculated_at | TIMESTAMP | NOT NULL |

Cambios vs versión anterior: se agregan `period_start`/`period_end` (VO `ConsumptionPeriod`).

### consumption_reports
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| user_id | BIGINT | NOT NULL, FK → users.id |
| property_id | BIGINT | NOT NULL, FK → properties.id |
| period_start | DATE | NOT NULL |
| period_end | DATE | NOT NULL |
| total_consumption | DECIMAL(10,2) | NOT NULL |
| total_consumption_unit | VARCHAR(50) | NOT NULL |
| is_automatic | BOOLEAN | NOT NULL |
| generated_at | TIMESTAMP | NOT NULL |

Cambios vs versión anterior: `period VARCHAR` + `start_date`/`end_date` se unifican en `period_start`/`period_end`; se agrega `total_consumption`.

### report_items
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| consumption_report_id | BIGINT | NOT NULL, FK → consumption_reports.id |
| device_id | BIGINT | NOT NULL, FK → devices.id |
| device_name | VARCHAR(255) | NOT NULL |
| total_consumption | DECIMAL(10,2) | NOT NULL |
| unit | VARCHAR(50) | NOT NULL |
| usage_frequency | INTEGER | NOT NULL |

### consumption_alerts
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| user_id | BIGINT | NOT NULL, FK → users.id |
| property_id | BIGINT | NOT NULL, FK → properties.id |
| device_id | BIGINT | NULL, FK → devices.id |
| severity | VARCHAR(50) | NOT NULL (LOW, MEDIUM, HIGH) |
| message | VARCHAR(500) | NOT NULL |
| threshold | DECIMAL(10,2) | NOT NULL |
| current_value | DECIMAL(10,2) | NOT NULL |
| is_read | BOOLEAN | NOT NULL (default false) |
| triggered_at | TIMESTAMP | NOT NULL |
| created_at / updated_at | TIMESTAMP | NOT NULL |

---

## ERD 5 — Subscriptions

Tablas propias: `plans`, `subscriptions`, `payments`. Referencia externa: `users` (IAM).

### plans
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| name | VARCHAR(255) | NOT NULL |
| plan_type | VARCHAR(50) | NOT NULL (FREE, PREMIUM) |
| price_amount | DECIMAL(10,2) | NOT NULL |
| price_currency | VARCHAR(10) | NOT NULL (ej. 'PEN', 'USD') |
| billing_cycle | VARCHAR(50) | NOT NULL (MONTHLY, YEARLY) |
| max_devices | INTEGER | NOT NULL |
| has_advanced_metrics | BOOLEAN | NOT NULL |
| has_custom_reports | BOOLEAN | NOT NULL |
| has_alerts | BOOLEAN | NOT NULL |
| has_unlimited_history | BOOLEAN | NOT NULL |
| is_active | BOOLEAN | NOT NULL |
| created_at / updated_at | TIMESTAMP | NOT NULL |

(Sin cambios de fondo vs versión anterior — esta tabla ya estaba bien.)

### subscriptions
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| user_id | BIGINT | NOT NULL, FK → users.id |
| plan_id | BIGINT | NOT NULL, FK → plans.id |
| status | VARCHAR(50) | NOT NULL (ACTIVE, CANCELLED, EXPIRED) |
| start_date | DATE | NOT NULL |
| end_date | DATE | NULL |
| auto_renew | BOOLEAN | NOT NULL |
| created_at / updated_at | TIMESTAMP | NOT NULL |

### payments
| Columna | Tipo | Restricciones |
|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT |
| subscription_id | BIGINT | NOT NULL, FK → subscriptions.id |
| amount_value | DECIMAL(10,2) | NOT NULL |
| amount_currency | VARCHAR(10) | NOT NULL |
| status | VARCHAR(50) | NOT NULL (PENDING, COMPLETED, FAILED) |
| external_payment_id | VARCHAR(255) | NULL |
| processed_at | TIMESTAMP | NULL |
| created_at / updated_at | TIMESTAMP | NOT NULL |

---

## Checklist al exportar de Vertabelo

- [ ] Motor del modelo: MySQL (no PostgreSQL)
- [ ] 5 imágenes: `erd-iam.png`, `erd-profiles.png`, `erd-device-management.png`, `erd-analytics.png`, `erd-subscriptions.png` en `assets/images/`
- [ ] Áreas/subject areas con el nombre del contexto propio y recuadros punteados para referencias externas
- [ ] Cardinalidades: users 1—1 profiles; users 1—* properties; properties 1—* spaces; spaces 1—* devices; simulation_sessions 1—* device_actions / usage_data; consumption_reports 1—* report_items; plans 1—* subscriptions; subscriptions 1—* payments
