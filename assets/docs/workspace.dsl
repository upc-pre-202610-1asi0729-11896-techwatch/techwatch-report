workspace "TechWatch" "Smart Home Management and Analysis Platform" {

    model {

        # Users
        homeOwner = person "Home Owner" "User who manages their house devices, visualizes metrics and consumption insights."
        apartmentResident = person "Apartment Resident" "User who manages their apartment devices, visualizes metrics and consumption insights."

        # External Systems
        paymentService = softwareSystem "Payment Service" "Processes user subscription transactions. Ex: Stripe." "External"

        # Main System
        techwatch = softwareSystem "TechWatch" "Web platform for Smart Home management and analysis." {

            landingPage = container "Landing Page" "Static website that presents the business model and redirects users to the web application." "HTML, CSS, JavaScript" {
                heroSection = component "HeroSection" "Main section with value proposition and call-to-action for each target segment." "HTML, CSS, JavaScript"
                featuresSection = component "FeaturesSection" "Section describing the platform's main features." "HTML, CSS, JavaScript"
                pricingSection = component "PricingSection" "Section presenting available subscription plans." "HTML, CSS, JavaScript"
                aboutSection = component "AboutSection" "Section presenting information about TechWatch and the team." "HTML, CSS, JavaScript"
                contactSection = component "ContactSection" "Contact section and inquiry form." "HTML, CSS, JavaScript"
                navBar = component "NavBar" "Main navigation bar of the Landing Page." "HTML, CSS, JavaScript"
            }

            webApp = container "Web Application" "SPA that allows users to manage their property, devices and visualize the metrics dashboard." "Angular" {

                # Web App - IAM BC
                webAuthService = component "AuthService" "Manages user authentication and JWT token storage." "Angular Service"

                # Web App - Profiles BC
                webProfileService = component "ProfileService" "Consumes REST endpoints for user profile and preferences management." "Angular Service"
                profileView = component "ProfileView" "View for managing the user profile and preferences." "Angular Component"

                # Web App - Device Management BC
                webPropertyService = component "PropertyService" "Consumes REST endpoints for property and space management." "Angular Service"
                webDeviceService = component "DeviceService" "Consumes REST endpoints for device management." "Angular Service"
                propertyView = component "PropertyView" "View for managing the property and its spaces." "Angular Component"
                deviceView = component "DeviceView" "View for managing devices by space." "Angular Component"

                # Web App - Analytics BC
                webAnalyticsService = component "AnalyticsService" "Consumes REST endpoints for metrics, insights and reports." "Angular Service"
                dashboardView = component "DashboardView" "Main view with property metrics and insights in an interactive dashboard." "Angular Component"
                reportsView = component "ReportsView" "View for consumption reports by period." "Angular Component"

                # Web App - Subscriptions BC
                webSubscriptionService = component "SubscriptionService" "Consumes REST endpoints for subscription management." "Angular Service"
                subscriptionView = component "SubscriptionView" "View for managing the user's subscription plan." "Angular Component"
            }

            remoteApp = container "Remote Control App" "Responsive web application that allows users to simulate device usage from a mobile device." "Angular" {
                remoteAuthService = component "AuthService" "Manages user authentication in the remote control app." "Angular Service"
                remoteSimulationService = component "SimulationService" "Consumes REST endpoints for simulation sessions and device control." "Angular Service"
                remoteHomeView = component "HomeView" "Main view showing the user's spaces and property." "Angular Component"
                remoteDeviceView = component "DeviceControlView" "Remote control view for devices by space, with options to turn on, turn off and modify parameters." "Angular Component"
                remoteSessionView = component "SessionView" "View showing the state of the active simulation session." "Angular Component"
            }

            api = container "RESTful API" "Exposes system services via a REST API. Contains the main business logic." "Spring Boot, Java" {

                # IAM BC
                iamInterfacesLayer = component "IAM Interfaces Layer" "Exposes REST endpoints for sign-up, sign-in and user management. Contains AuthenticationController and UsersController." "Spring MVC REST Controllers"
                iamApplicationLayer = component "IAM Application Layer" "Handles user registration and authentication use cases. Contains UserCommandService and UserQueryService." "Spring Services"
                iamDomainLayer = component "IAM Domain Layer" "Contains the IAM domain model. Contains the User aggregate, EmailAddress and Role value objects, commands and queries." "Domain Model"
                iamInfrastructureLayer = component "IAM Infrastructure Layer" "Contains persistence and security implementations. Contains UserRepository, TokenService (JWT), HashingService (BCrypt) and the authorization filter." "Spring Data JPA, Spring Security"

                # Profiles BC
                profilesInterfacesLayer = component "Profiles Interfaces Layer" "Exposes REST endpoints for profile and preferences management. Contains ProfilesController." "Spring MVC REST Controllers"
                profilesApplicationLayer = component "Profiles Application Layer" "Handles profile management use cases. Contains ProfileCommandService and ProfileQueryService." "Spring Services"
                profilesDomainLayer = component "Profiles Domain Layer" "Contains the Profiles domain model. Contains the Profile aggregate with PersonName and Preferences value objects, commands and queries." "Domain Model"
                profilesInfrastructureLayer = component "Profiles Infrastructure Layer" "Contains persistence implementations. Contains ProfileRepository." "Spring Data JPA"

                # Device Management BC (includes device simulation)
                dmInterfacesLayer = component "DM Interfaces Layer" "Exposes REST endpoints for property, device and simulation session management. Contains PropertiesController, DevicesController and SimulationSessionsController." "Spring MVC REST Controllers"
                dmApplicationLayer = component "DM Application Layer" "Handles property, device and simulation use cases. Contains command/query services for Property, Device and SimulationSession." "Spring Services"
                dmDomainLayer = component "DM Domain Layer" "Contains the Device Management domain model. Contains the Property (with Spaces), Device and SimulationSession aggregates, commands, queries and domain events." "Domain Model"
                dmInfrastructureLayer = component "DM Infrastructure Layer" "Contains persistence implementations. Contains PropertyRepository, DeviceRepository and SimulationSessionRepository." "Spring Data JPA"

                # Analytics BC
                anInterfacesLayer = component "AN Interfaces Layer" "Exposes REST endpoints for metrics, dashboard, reports and alerts. Contains MetricsController, DashboardController, ReportsController and AlertsController." "Spring MVC REST Controllers"
                anApplicationLayer = component "AN Application Layer" "Handles metrics calculation, report generation and alerting use cases. Contains command/query services and the UsageDataGeneratedEvent handler." "Spring Services"
                anDomainLayer = component "AN Domain Layer" "Contains the Analytics domain model. Contains the ConsumptionMetric, ConsumptionReport (with ReportItems) and ConsumptionAlert aggregates, commands and queries." "Domain Model"
                anInfrastructureLayer = component "AN Infrastructure Layer" "Contains persistence implementations. Contains ConsumptionMetricRepository, ConsumptionReportRepository and ConsumptionAlertRepository." "Spring Data JPA"

                # Subscriptions BC
                subInterfacesLayer = component "SUB Interfaces Layer" "Exposes REST endpoints for plans, subscriptions and payments. Contains PlansController, SubscriptionsController and PaymentsController." "Spring MVC REST Controllers"
                subApplicationLayer = component "SUB Application Layer" "Handles subscription and payment use cases. Contains command/query services for Plan, Subscription and Payment." "Spring Services"
                subDomainLayer = component "SUB Domain Layer" "Contains the Subscriptions domain model. Contains the Plan, Subscription and Payment aggregates with Money and BillingCycle value objects, commands and queries." "Domain Model"
                subInfrastructureLayer = component "SUB Infrastructure Layer" "Contains persistence and integration implementations. Contains PlanRepository, SubscriptionRepository, PaymentRepository and the ExternalPaymentService adapter." "Spring Data JPA"
            }

            db = container "Database" "Stores users, profiles, properties, devices, simulation sessions, metrics, reports, alerts, plans, subscriptions and payments." "MySQL"
        }

        # User relations with containers
        homeOwner -> landingPage "Visits to learn about the product"
        homeOwner -> webApp "Manages property, devices and visualizes dashboard"
        homeOwner -> remoteApp "Simulates device usage"
        apartmentResident -> landingPage "Visits to learn about the product"
        apartmentResident -> webApp "Manages property, devices and visualizes dashboard"
        apartmentResident -> remoteApp "Simulates device usage"

        # Container relations
        landingPage -> webApp "Redirects user via call-to-action"
        webApp -> api "Consumes endpoints via HTTPS/JSON"
        remoteApp -> api "Consumes endpoints via HTTPS/JSON"
        api -> db "Reads and writes data via JDBC"
        api -> paymentService "Processes subscription payments via HTTPS"

        # Landing Page internal relations
        homeOwner -> heroSection "Views value proposition"
        apartmentResident -> heroSection "Views value proposition"
        heroSection -> webApp "Redirects via call-to-action"
        navBar -> heroSection "Navigates to"
        navBar -> featuresSection "Navigates to"
        navBar -> pricingSection "Navigates to"
        navBar -> aboutSection "Navigates to"
        navBar -> contactSection "Navigates to"

        # Web Application internal relations
        homeOwner -> dashboardView "Views metrics and insights"
        homeOwner -> propertyView "Manages property and spaces"
        homeOwner -> deviceView "Manages devices"
        homeOwner -> reportsView "Views consumption reports"
        homeOwner -> subscriptionView "Manages subscription"
        homeOwner -> profileView "Manages profile and preferences"
        dashboardView -> webAnalyticsService "Requests metrics and insights"
        propertyView -> webPropertyService "Requests property management"
        deviceView -> webDeviceService "Requests device management"
        reportsView -> webAnalyticsService "Requests reports"
        subscriptionView -> webSubscriptionService "Requests subscription management"
        profileView -> webProfileService "Requests profile management"
        webAuthService -> api "Authenticates user via HTTPS/JSON"
        webProfileService -> api "Consumes profile endpoints via HTTPS/JSON"
        webPropertyService -> api "Consumes property endpoints via HTTPS/JSON"
        webDeviceService -> api "Consumes device endpoints via HTTPS/JSON"
        webAnalyticsService -> api "Consumes metrics endpoints via HTTPS/JSON"
        webSubscriptionService -> api "Consumes subscription endpoints via HTTPS/JSON"

        # Remote Control App internal relations
        homeOwner -> remoteHomeView "Views spaces and property"
        homeOwner -> remoteDeviceView "Controls devices"
        homeOwner -> remoteSessionView "Views active session"
        remoteHomeView -> remoteSimulationService "Requests property data"
        remoteDeviceView -> remoteSimulationService "Sends control commands"
        remoteSessionView -> remoteSimulationService "Queries session state"
        remoteAuthService -> api "Authenticates user via HTTPS/JSON"
        remoteSimulationService -> api "Consumes simulation endpoints via HTTPS/JSON"

        # API internal relations - IAM BC
        webApp -> iamInterfacesLayer "Signs up and signs in via HTTPS/JSON"
        remoteApp -> iamInterfacesLayer "Signs in via HTTPS/JSON"
        iamInterfacesLayer -> iamApplicationLayer "Delegates use cases"
        iamApplicationLayer -> iamDomainLayer "Uses domain model"
        iamApplicationLayer -> iamInfrastructureLayer "Accesses data and security services"
        iamInfrastructureLayer -> db "Reads and writes via JDBC"
        iamApplicationLayer -> profilesApplicationLayer "Creates profile on user registration (ACL)"

        # API internal relations - Profiles BC
        webApp -> profilesInterfacesLayer "Manages profile via HTTPS/JSON"
        profilesInterfacesLayer -> profilesApplicationLayer "Delegates use cases"
        profilesApplicationLayer -> profilesDomainLayer "Uses domain model"
        profilesApplicationLayer -> profilesInfrastructureLayer "Accesses data"
        profilesInfrastructureLayer -> db "Reads and writes via JDBC"

        # API internal relations - Device Management BC
        webApp -> dmInterfacesLayer "Manages properties and devices via HTTPS/JSON"
        remoteApp -> dmInterfacesLayer "Manages simulation sessions via HTTPS/JSON"
        dmInterfacesLayer -> dmApplicationLayer "Delegates use cases"
        dmApplicationLayer -> dmDomainLayer "Uses domain model"
        dmApplicationLayer -> dmInfrastructureLayer "Accesses data"
        dmInfrastructureLayer -> db "Reads and writes via JDBC"
        dmApplicationLayer -> anApplicationLayer "Publishes generated usage data (domain event)"
        dmApplicationLayer -> subApplicationLayer "Checks plan device limit (ACL)"

        # API internal relations - Analytics BC
        webApp -> anInterfacesLayer "Queries metrics, reports and alerts via HTTPS/JSON"
        anInterfacesLayer -> anApplicationLayer "Delegates use cases"
        anApplicationLayer -> anDomainLayer "Uses domain model"
        anApplicationLayer -> anInfrastructureLayer "Accesses data"
        anInfrastructureLayer -> db "Reads and writes via JDBC"

        # API internal relations - Subscriptions BC
        webApp -> subInterfacesLayer "Manages subscriptions via HTTPS/JSON"
        subInterfacesLayer -> subApplicationLayer "Delegates use cases"
        subApplicationLayer -> subDomainLayer "Uses domain model"
        subApplicationLayer -> subInfrastructureLayer "Accesses data"
        subInfrastructureLayer -> paymentService "Processes payments via HTTPS"
        subInfrastructureLayer -> db "Reads and writes via JDBC"
    }

    views {

        systemContext techwatch "Context" {
            include *
            autoLayout lr
        }

        container techwatch "Containers" {
            include *
            autoLayout lr
        }

        # General Component Diagrams
        component api "Components-API-General" {
            include *
            autoLayout lr
        }

        component webApp "Components-WebApp" {
            include *
            autoLayout lr
        }

        component remoteApp "Components-RemoteApp" {
            include *
            autoLayout lr
        }

        component landingPage "Components-LandingPage" {
            include *
            autoLayout lr
        }

        # API Component Diagrams by Bounded Context
        component api "Components-API-IAM" {
            include iamInterfacesLayer
            include iamApplicationLayer
            include iamDomainLayer
            include iamInfrastructureLayer
            include profilesApplicationLayer
            include webApp
            include db
            autoLayout lr
        }

        component api "Components-API-Profiles" {
            include profilesInterfacesLayer
            include profilesApplicationLayer
            include profilesDomainLayer
            include profilesInfrastructureLayer
            include webApp
            include db
            autoLayout lr
        }

        component api "Components-API-DeviceManagement" {
            include dmInterfacesLayer
            include dmApplicationLayer
            include dmDomainLayer
            include dmInfrastructureLayer
            include anApplicationLayer
            include subApplicationLayer
            include webApp
            include remoteApp
            include db
            autoLayout lr
        }

        component api "Components-API-Analytics" {
            include anInterfacesLayer
            include anApplicationLayer
            include anDomainLayer
            include anInfrastructureLayer
            include webApp
            include db
            autoLayout lr
        }

        component api "Components-API-Subscriptions" {
            include subInterfacesLayer
            include subApplicationLayer
            include subDomainLayer
            include subInfrastructureLayer
            include webApp
            include paymentService
            include db
            autoLayout lr
        }

        styles {
            element "Person" {
                shape Person
                background #08427B
                color #ffffff
            }
            element "Software System" {
                background #1168BD
                color #ffffff
            }
            element "Container" {
                background #438DD5
                color #ffffff
            }
            element "Component" {
                background #85BBF0
                color #000000
            }
            element "External" {
                background #999999
                color #ffffff
            }
        }
    }
}
