# Arquitectura y Flujo Global de la Aplicación

## 1. Estructura de Proyecto (Clean Architecture Feature-First)

```text
lib/
├── app/
│   ├── config/
│   └── core/
└── features/
    ├── auth_users/
    ├── specialists/
    ├── treatment_photos/
    ├── patients_compliance/
    ├── catalog_services/
    ├── marketplace_citas/
    ├── treatment_execution/
    ├── payments_stripe/
    ├── admin_config/
    └── reports_dashboards/

## 2. Diagrama del Flujo de Negocio y Módulos (Mermaid)
    graph TD
    %% --------------------------------------------------
    %% 1. ESTRUCTURA DE ARQUITECTURA (Clean Architecture)
    %% --------------------------------------------------
    subgraph Architecture ["🏗️ Arquitectura Flutter (Feature-First)"]
        direction TB
        AppConfig["lib/app/config (routes, theme, env)"]
        AppCore["lib/app/core (network, errors, utils, security)"]
        
        subgraph FeaturePattern ["Estructura de cada Feature (Módulos 1-10)"]
            Presentation["Presentation Layer (Cubit, Screens, Widgets)"]
            Domain["Domain Layer (Entities, Repositories, UseCases)"]
            Data["Data Layer (DataSources/Supabase, Models, RepositoriesImpl)"]
            
            Presentation -->|Invoca| Domain
            Data ..->|Implementa| Domain
        end
    end

    %% --------------------------------------------------
    %% 2. MÓDULOS DE DOMINIO Y ENTIDADES (1 a 9)
    %% --------------------------------------------------
    subgraph M1 ["M1: auth_users"]
        Profiles["profiles / auth.users (1:1)"]
        Roles["roles (Admin, Specialist, Patient)"]
        FCM["dispositivos_usuario (FCM Tokens)"]
    end

    subgraph M2 ["M2: specialists"]
        SpecAcc["especialistas"]
        Regentes["medicos_regentes (1:N)"]
        Docs["documentos & contratos (Firma Digital)"]
        Geo["ubicaciones_especialista (PostGIS Point)"]
    end

    subgraph M3 ["M3: patients_compliance"]
        Patients["pacientes"]
        EvalSalud["evaluaciones_salud"]
        Telemed["validaciones_telemedicina (Qualify)"]
    end

    subgraph M4 ["M4: catalog_services"]
        Servicios["categorias_servicio & servicios"]
        Prereq["Prerrequisitos (FaceMap, Consent, Fotos)"]
    end

    subgraph M5 ["M5: marketplace_citas"]
        Solicitudes["solicitudes (First-Accept)"]
        Citas["citas"]
        DirPac["direcciones_paciente"]
    end

    subgraph M6 ["M6: treatment_execution"]
        Tratamiento["tratamientos (Inmutable)"]
        FaceMap["face_maps & face_map_puntos (X,Y)"]
        Prods["productos_aplicados (Lote/Venc)"]
    end

    subgraph M6b ["M6.4: treatment_photos"]
        Fotos["fotografias_tratamiento (PRE/POST) — bucket fotografias-tratamiento"]
    end

    subgraph M7 ["M7: payments_stripe"]
        Transacciones["transacciones & pagos (Stripe)"]
        Comisiones["comisiones & liquidaciones"]
    end

    subgraph M8_9 ["M8 & M9: Admin & Reports"]
        Config["configuracion_sistema & RLS"]
        Metrics["vistas SQL & evaluaciones_servicio"]
    end

    %% --------------------------------------------------
    %% 3. FLUJO DE NEGOCIO Y REGLAS CRÍTICAS
    %% --------------------------------------------------
    subgraph BusinessFlow ["🔄 Flujo End-to-End de Servicio"]
        direction TB
        
        Start([Inicio Reserva]) --> CheckAuth{¿Sesión / RLS Valido?}
        CheckAuth -- No --> Deny[Acceso Denegado]
        CheckAuth -- Sí --> CheckCompliance{M3: ¿Telemedicina y Salud Válidos?}
        
        CheckCompliance -- No / Vencido --> BlockReserva[❌ RN-020/022: Bloquear Cita]
        
        CheckCompliance -- OK --> CreateReq[M5: Crear Solicitud Citas + Depósito Stripe $30 USD]
        CreateReq --> FindGeo[M2: Búsqueda Geofencing PostGIS]
        
        FindGeo --> FirstAccept{M5: First-Accept por Especialista}
        FirstAccept -- Pendiente --> HideDir[🔒 RN-018: Dirección Paciente Oculta]
        
        FirstAccept -- Aceptada --> ConfirmCita[M5: Cita Creada]
        ConfirmCita --> ShowDir[🔓 RN-018: Revelar Dirección al Especialista]
        
        ConfirmCita --> ExecFlow["M6: Flujo de Ejecución Médica"]
        
        subgraph StepExec ["Flujo Clínico (M6)"]
            ExecFlow --> Arrival[1. Llegada]
            Arrival --> InteractiveFM[2. Face Map interactivo X,Y]
            InteractiveFM --> LogProds[3. Registro Lote/Venc Productos]
            LogProds --> Photos[4. Fotos PRE/POST (M6.4 treatment_photos)]
            Photos --> Sign[5. Firma Digital]
        end
        
        Sign --> FreezeRecord[🔒 RN-044: Registro Clínico Congelado]
        
        FreezeRecord --> FinalPayment[M7: Cobro Saldo Restante Stripe]
        FinalPayment --> FreezeComms[🔒 RN-053: Congelar Comisiones]
        FreezeComms --> Settlement[M7: Liquidación Semanal Especialistas]
        Settlement --> End([Fin del Proceso])
    end

    %% Relaciones inter-módulos
    Profiles --> Patients
    Profiles --> SpecAcc
    SpecAcc --> Geo
    Patients --> EvalSalud
    EvalSalud --> CreateReq
    Servicios --> Prereq
    ConfirmCita --> ExecFlow
    Tratamiento --> Fotos
    ExecFlow --> Photos