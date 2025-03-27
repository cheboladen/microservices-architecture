# Infraestructura GCP para Microservicios con Terraform (PoC)

## Contexto y Elección de Plataforma

Este repositorio presenta una solución de infraestructura como código (IaC) utilizando Terraform para desplegar los cimientos de una aplicación web basada en microservicios en Google Cloud Platform (GCP).

El escenario original permitía elegir entre AWS y GCP. Si bien mi experiencia previa se inclina hacia otras áreas, actualmente estoy inmerso en el proceso de aprendizaje y certificación en Google Cloud. Por ello, **opté por utilizar GCP para este proyecto**, viéndolo como una excelente oportunidad para aplicar y profundizar en sus servicios y arquitecturas, especialmente GKE y sus servicios gestionados asociados. El objetivo ha sido diseñar una infraestructura inicial robusta, siguiendo las directrices del [Google Cloud Well-Architected Framework (WAF)](https://cloud.google.com/architecture/framework).

Esta configuración debe considerarse una **Prueba de Concepto (PoC) o Versión 1**. Representa una base sólida sobre la cual evolucionar, pero no incluye optimizaciones avanzadas ni todos los componentes de un entorno de producción a gran escala.

Para dar forma a los requisitos de almacenamiento (PostgreSQL, Redis, mensajería asíncrona tipo Kafka), se ha modelado mentalmente una estructura de microservicios típica, aunque sin disponer del código real:

*   **API Gateway (`entrypoint-gateway`):** Punto único de entrada para las peticiones externas.
*   **Servicio de Autenticación/Usuarios (`auth-user-service`):** Dependiente de persistencia relacional (**Cloud SQL - PostgreSQL**).
*   **Servicio de Catálogo (`catalog-service`):** Podría beneficiarse de caché para consultas frecuentes (**Memorystore - Redis**) además de la base de datos principal (**Cloud SQL**).
*   **Servicio de Pedidos (`order-processing-service`):** Utilizaría **Cloud SQL** y generaría eventos asíncronos (**Pub/Sub**) tras crear un pedido.
*   **Servicio de Notificaciones (`notification-service`):** Reaccionaría a eventos de **Pub/Sub** para realizar acciones secundarias.

Este modelo conceptual ayuda a validar la necesidad de los distintos componentes de infraestructura y a definir sus interconexiones y requisitos de seguridad.

**Alcance de esta Configuración Terraform:** El código provisiona la red VPC, subredes, reglas de firewall, Cloud NAT, el cluster GKE Standard con autoscaling, las instancias gestionadas de Cloud SQL y Memorystore, los recursos de Pub/Sub, la configuración de Secret Manager y las identidades/permisos IAM mediante Workload Identity. **No incluye** el despliegue de las aplicaciones, pipelines de CI/CD, monitorización avanzada o estrategias de recuperación ante desastres complejas.

## Descripción General de la Arquitectura

La infraestructura desplegada en GCP se compone de:

*   **Red VPC Custom:** (`main-vpc`) para control explícito.
*   **Subredes Regionales:** Pública (`public-subnet-madrid`) y Privada (`private-subnet-madrid`) para aislamiento.
*   **Google Kubernetes Engine (GKE):** Cluster Standard regional (`main-cluster` en `europe-southwest1`) con nodos privados y autoscaling.
*   **Cloud SQL para PostgreSQL:** Instancia HA (`main-postgres-instance`) con IP privada.
*   **Memorystore para Redis:** Instancia Standard HA (`main-redis-instance`) con IP privada.
*   **Pub/Sub:** Para mensajería asíncrona serverless.
*   **Cloud NAT:** Acceso saliente seguro desde la subred privada.
*   **Secret Manager:** Almacenamiento seguro de credenciales.
*   **IAM y Workload Identity:** Permisos granulares y acceso seguro a APIs GCP desde GKE.
*   **Firewall de VPC:** Reglas de mínimo privilegio.

*(Referencia: Ver el archivo `architecture.png` para una representación visual).*

## Decisiones de Diseño y Justificación (WAF)

Las decisiones clave tomadas se basan en los requisitos y las mejores prácticas del WAF:

### 1. Networking

*   **VPC Custom Mode:** Control explícito y seguridad mejorada (WAF: Excelencia Operativa, Seguridad).
*   **Subredes Pública/Privada:** Aislamiento de cargas de trabajo para seguridad (WAF: Seguridad).
*   **Cloud NAT:** Salida segura a Internet sin exponer IPs privadas (WAF: Seguridad, Excelencia Operativa).
*   **Private Service Access (PSA):** Conexión privada a servicios gestionados (Cloud SQL/Memorystore) (WAF: Seguridad).
*   **Reglas de Firewall VPC:** Mínimo privilegio, usando etiquetas de red. *Nota: La regla Egress se simplificó para este PoC.* (WAF: Seguridad).

### 2. Compute (GKE)

*   **Modo GKE Standard:** Permite configurar explícitamente Node Pools y autoscaling.
*   **Cluster Regional:** Alta disponibilidad del plano de control (WAF: Fiabilidad).
*   **Acceso al Cluster:** Endpoint público asegurado con Redes Autorizadas (`215.215.0.0/16`). Nodos privados. Balance seguridad/operatividad (WAF: Seguridad, Excelencia Operativa).
*   **Autoscaling:** Cluster Autoscaler con límites (1-3 nodos/zona). Control de costes y disponibilidad (WAF: Fiabilidad, Rendimiento, Optimización de Costes). Máquina `e2-medium` inicial.
*   **Cuenta de Servicio de Nodo:** SA dedicada (`gke-node-sa`) con permisos mínimos (WAF: Seguridad).

### 3. Data Storage

*   **Cloud SQL (PostgreSQL):** Servicio gestionado, HA, backups/PITR, IP privada (WAF: Excelencia Operativa, Fiabilidad, Seguridad).
*   **Memorystore (Redis):** Servicio gestionado, Standard HA, IP privada (WAF: Excelencia Operativa, Fiabilidad, Seguridad).
*   **Pub/Sub:** Solución GCP nativa, serverless y escalable para mensajería asíncrona (WAF: Excelencia Operativa, Escalabilidad, Optimización de Costes). Cumple la *función* del requisito de mensajería.
*   **Autenticación:** Contraseñas gestionadas vía **Secret Manager**. Acceso desde GKE con Workload Identity. Cloud SQL usa Auth Proxy (TLS); Redis usa AUTH + Cifrado en Tránsito (WAF: Seguridad, Excelencia Operativa).

### 4. Security (Integrado)

*   **IAM y Workload Identity:** SA dedicadas por componente y microservicio. Workload Identity para acceso sin claves a APIs GCP desde Pods (WAF: Seguridad, Excelencia Operativa).
*   **Gestión de Secretos:** Google Secret Manager.
*   **Network Policies:** Habilitadas en GKE para futura micro-segmentación (WAF: Seguridad).
*   **Protección de Recursos:** `deletion_protection = true` para Cloud SQL/Memorystore (WAF: Fiabilidad, Excelencia Operativa).
*   **Hardening GKE:** GKE Security Posture Dashboard habilitado (básico).

## Asunciones Realizadas

Para definir esta configuración, se partió de las siguientes asunciones:

*   **Plataforma:** GCP elegido como entorno de aprendizaje y aplicación de conceptos.
*   **Región:** `europe-southwest1` (Madrid).
*   **Redes:** Los CIDRs propuestos son adecuados y no conflictivos. El CIDR `215.215.0.0/16` es representativo de la red permitida para acceso al master GKE.
*   **Aplicación/Microservicios:** Modelo conceptual simple (gateway, auth, catalog, order, notification) para guiar el diseño. Cluster GKE único para PoC.
*   **GKE:** Modo Standard, endpoint público + Redes Autorizadas, `e2-medium` y 1-3 nodos/zona como inicio. Versión GKE reciente (`~1.11.x` o estable). Namespace `default` para simplicidad en Workload Identity.
*   **Data Storage:** Versiones DB/Redis adecuadas. Tamaños iniciales para PoC. HA requerida. Pub/Sub cumple el rol funcional de mensajería. Autenticación vía Secret Manager es suficiente para PoC. Rango de IPs de Servicio GKE gestionado por Google es adecuado.
*   **Seguridad:** Regla Egress permisiva es simplificación temporal. Puertos Health Check no especificados. GKE Security Posture básico.
*   **Operaciones:** Backend remoto GCS pre-creado. No hay CI/CD. Monitorización básica.

## Cómo Usar

Esta sección describe cómo desplegar la infraestructura definida en este repositorio utilizando Terraform. Tienes dos opciones principales para gestionar el archivo de estado de Terraform (`terraform.tfstate`), que es crucial porque registra qué infraestructura ha creado Terraform:

**Opción 1: Usando Backend Remoto GCS (Recomendado para colaboración y seguridad)**

Este es el método **recomendado**, especialmente si trabajas en equipo o quieres una gestión más robusta del estado. Almacena el archivo de estado de forma centralizada y segura en un bucket de Google Cloud Storage y proporciona bloqueo para evitar que varias personas apliquen cambios simultáneamente.

1.  **Prerrequisitos:**
    *   Instalar Terraform CLI (versión `>= 1.11.0`).
    *   Instalar Google Cloud SDK (`gcloud`) y autenticarse (`gcloud auth login`, `gcloud auth application-default login`).
    *   Tener un proyecto GCP con facturación habilitada.
    *   **¡Importante!** Crear manualmente un bucket de Google Cloud Storage en tu proyecto GCP. Este bucket almacenará el archivo de estado remoto. Asegúrate de que tenga activado el control de versiones de objetos para poder recuperar estados anteriores si fuera necesario. Anota el nombre exacto del bucket.
        *   Ejemplo comando gcloud: `gcloud storage buckets create gs://NOMBRE_BUCKET_UNICO --project=TU_PROYECTO_ID --location=TU_REGION --uniform-bucket-level-access --enable-versioning` (Asegúrate de que el nombre del bucket sea globalmente único).
2.  **Configuración:**
    *   Clonar este repositorio.
    *   **Importante:** Editar el archivo `backend.tf`. Reemplaza `"tu-bucket-terraform-state-unico"` con el nombre real del bucket GCS que acabas de crear.
    *   Crear un archivo `terraform.tfvars` (basado en `terraform.tfvars.example`) y definir al menos el valor para `gcp_project_id`. Puedes sobrescribir otras variables si es necesario.
3.  **Despliegue:**
    *   Abrir una terminal en el directorio raíz del repositorio.
    *   Ejecutar `terraform init`. Terraform detectará la configuración del backend GCS, te pedirá confirmación si ya existe estado, y descargará los providers.
    *   Ejecutar `terraform plan -out=tfplan` para previsualizar los cambios.
    *   Revisar el plan (`tfplan`).
    *   Ejecutar `terraform apply tfplan` para crear la infraestructura. Confirmar con `yes`. El archivo de estado se guardará en el bucket GCS.
4.  **Limpieza:**
    *   Para destruir la infraestructura creada, ejecutar `terraform destroy`. Confirmar con `yes`. El estado en GCS se actualizará.

**Opción 2: Usando Backend Local (Para pruebas individuales y rápidas)**

Esta opción es más simple para empezar si estás trabajando solo y no necesitas las características de colaboración o seguridad avanzada del estado remoto. Terraform guardará el archivo `terraform.tfstate` directamente en el directorio local donde ejecutes los comandos. **¡Ten cuidado de no borrar este archivo accidentalmente ni subirlo a un control de versiones público si contiene información sensible!**

1.  **Prerrequisitos:**
    *   Instalar Terraform CLI (versión `>= 1.11.0`).
    *   Instalar Google Cloud SDK (`gcloud`) y autenticarse (`gcloud auth login`, `gcloud auth application-default login`).
    *   Tener un proyecto GCP con facturación habilitada.
2.  **Configuración:**
    *   Clonar este repositorio.
    *   **Importante:** **Eliminar o comentar completamente el contenido del archivo `backend.tf`**. Esto hará que Terraform utilice su backend local por defecto. Puedes renombrarlo, por ejemplo, a `backend.tf.disabled`.
    *   Crear un archivo `terraform.tfvars` (basado en `terraform.tfvars.example`) y definir al menos el valor para `gcp_project_id`. Puedes sobrescribir otras variables si es necesario.
3.  **Despliegue:**
    *   Abrir una terminal en el directorio raíz del repositorio.
    *   Ejecutar `terraform init`. Terraform se inicializará usando el backend local y descargará los providers.
    *   Ejecutar `terraform plan -out=tfplan` para previsualizar los cambios.
    *   Revisar el plan (`tfplan`).
    *   Ejecutar `terraform apply tfplan` para crear la infraestructura. Confirmar con `yes`. El archivo `terraform.tfstate` (y backups) se crearán en tu directorio local.
4.  **Limpieza:**
    *   Para destruir la infraestructura creada, ejecutar `terraform destroy`. Confirmar con `yes`. Terraform usará el archivo de estado local para saber qué destruir.

**¿Cuál elegir?** Para este ejercicio de entrevista, si solo necesitas demostrar la funcionalidad y vas a ejecutarlo tú mismo, la **Opción 2 (Local)** puede ser suficiente y más rápida de configurar. Para cualquier escenario que implique colaboración, persistencia segura del estado o flujos de trabajo más allá de una prueba simple, la **Opción 1 (GCS)** es la práctica estándar y recomendada. Este repositorio está configurado por defecto para la Opción 1.

## Posibles Mejoras Futuras

*   **Seguridad Red:** Reglas Egress estrictas, VPC Service Controls.
*   **Network Policies:** Definir políticas K8s específicas.
*   **Monitorización/Alertas:** Dashboards, SLOs, Alertas.
*   **CI/CD:** Pipelines para IaC y aplicación (Cloud Build/Deploy).
*   **Optimización Costes:** Recommender, CUDs, Spot VMs.
*   **DR:** Estrategia multi-región.
*   **Hardening:** Binary Authorization, Security Posture avanzado.