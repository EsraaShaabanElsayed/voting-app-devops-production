# Voting App - Distributed Microservices Architecture

![CI/CD Status](https://github.com/esraashaabanelsayed/voting-app-devops-production/actions/workflows/ci-cd.yml/badge.svg)

A cloud-native, distributed voting application built with a microservices architecture. This project demonstrates modern DevOps practices including containerization, orchestration with Kubernetes, and a complete CI/CD pipeline.

## 🏗️ Architecture

The application consists of five microservices working together:

![Architecture Diagram](./architecture.excalidraw.png)

| Service | Technology | Description |
|---------|------------|-------------|
| **Vote** | Python (Flask) | Frontend web app for users to cast votes. |
| **Result** | Node.js | Frontend web app displaying real-time voting results. |
| **Worker** | .NET | Background worker that consumes votes from Redis and stores them in PostgreSQL. |
| **Redis** | Redis | In-memory message broker for queuing votes. |
| **PostgreSQL** | PostgreSQL | Persistent database for storing vote counts. |

### Data Flow
1.  **User Interaction**: Users vote via the **Vote** app (Python).
2.  **Queueing**: The vote is pushed to a **Redis** queue.
3.  **Processing**: The **Worker** (.NET) consumes the vote from Redis.
4.  **Storage**: The Worker persists the vote in **PostgreSQL**.
5.  **Visualization**: The **Result** app (Node.js) fetches updated counts from DB and updates the UI in real-time.

---

## 🚀 Getting Started

### Prerequisites
- Docker & Docker Compose
- Minikube (for Kubernetes deployment)
- kubectl

### Running Locally (Docker Compose)

The easiest way to run the application locally is using Docker Compose.

```bash
# Clone the repository
git clone https://github.com/esraashaabanelsayed/voting-app-devops-production.git
cd voting-app-devops-production

# Start the application
docker compose up -d
```

Access the services:
- **Vote App**: [http://localhost:8080](http://localhost:8080)
- **Result App**: [http://localhost:8081](http://localhost:8081)

### Deploying to Kubernetes (Minikube)

To deploy the application to a local Kubernetes cluster:

1.  **Start Minikube**:
    ```bash
    minikube start --driver=docker
    ```

2.  **Deploy Resources**:
    The project includes a comprehensive set of manifests in the `k8s/` directory.

    ```bash
    # Apply all manifests
    kubectl create namespace voting-app
    kubectl apply -f k8s/base/namespace.yml
    kubectl apply -f k8s/base/configmaps/ -n voting-app
    kubectl apply -f k8s/base/secrets/ -n voting-app
    
    # Deploy databases (using Helm or manifests)
    # ... (See CI/CD for Helm details, or use provided manifests if available)
    
    # Deploy Apps
    kubectl apply -f k8s/base/vote/ -n voting-app
    kubectl apply -f k8s/base/result/ -n voting-app
    kubectl apply -f k8s/base/worker/ -n voting-app
    ```

3.  **Access the App**:
    ```bash
    minikube service vote -n voting-app
    minikube service result -n voting-app
    ```

---

## 🔄 CI/CD Pipeline

This project uses **GitHub Actions** for Continuous Integration and Deployment.

### Workflow: `ci-cd.yml`

The pipeline is triggered on pushes to the `main` branch and performs the following steps:

1.  **Build & Push**:
    - Builds Docker images for `vote`, `result`, and `worker` services.
    - Pushes images to GitHub Container Registry (GHCR).
    - Tags images with both `latest` and the Git SHA.

2.  **Security Scanning**:
    - Scans built images for vulnerabilities using **Trivy**.
    - Uploads SARIF reports to GitHub Security.

3.  **Deploy to Minikube (Integration Test)**:
    - Spins up a Minikube cluster inside the GitHub Runner.
    - Deploys the application using the newly built images (injecting the specific SHA).
    - Verifies deployment stability using `kubectl wait`.

4.  **Smoke Tests**:
    - Runs connectivity tests to ensure the Vote and Result services are accessible.

---

## 🛠️ Technologies

- **Containerization**: Docker
- **Orchestration**: Kubernetes (K8s)
- **CI/CD**: GitHub Actions
- **Infrastructure as Code**: Terraform (planned/included in `terraform/`)
- **Languages**: Python, Node.js, C# (.NET), Shell

## 📜 License

This project is open source and available under the [MIT License](LICENSE).