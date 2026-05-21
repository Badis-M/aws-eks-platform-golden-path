from enum import Enum
from typing import List
from uuid import uuid4

from fastapi import FastAPI # type: ignore
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


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}


@app.get("/ready")
def ready() -> dict[str, str]:
    return {"status": "ready"}


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