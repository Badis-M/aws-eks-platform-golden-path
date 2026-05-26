from enum import Enum
from typing import List
from uuid import uuid4

from fastapi import FastAPI, Request, Response # type: ignore
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, generate_latest # type: ignore
from pydantic import BaseModel, Field # type: ignore


class IncidentSeverity(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class IncidentCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=120)
    severity: IncidentSeverity = IncidentSeverity.LOW


class Incident(BaseModel):
    id: str
    title: str
    severity: IncidentSeverity
    status: str = "open"


app = FastAPI(
    title="Incident API",
    description="Demo API for the AWS EKS Platform Golden Path project.",
    version="0.1.0",
)

incidents: List[Incident] = []

APP_INFO = Gauge(
    "incident_api_info",
    "Incident API application information.",
    ["app", "version"],
)

HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total HTTP requests processed by the Incident API.",
    ["method", "path", "status_code"],
)

APP_INFO.labels(app="incident-api", version=app.version).set(1)


@app.middleware("http")
async def record_http_requests(request: Request, call_next):
    response = await call_next(request)
    HTTP_REQUESTS_TOTAL.labels(
        method=request.method,
        path=request.url.path,
        status_code=str(response.status_code),
    ).inc()
    return response


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}


@app.get("/ready")
def ready() -> dict[str, str]:
    return {"status": "ready"}


@app.get("/metrics")
def metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/incidents", response_model=list[Incident])
def list_incidents() -> list[Incident]:
    return incidents


@app.post("/incidents", response_model=Incident, status_code=201)
def create_incident(payload: IncidentCreate) -> Incident:
    incident = Incident(
        id=str(uuid4()),
        title=payload.title,
        severity=payload.severity,
    )
    incidents.append(incident)
    return incident