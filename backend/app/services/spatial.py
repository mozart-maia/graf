import math
from typing import Tuple

# Raio médio da Terra em metros
EARTH_RADIUS_METERS = 6371000.0


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calcula a distância em metros entre duas coordenadas geográficas
    usando a fórmula de Haversine.
    """
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))

    return EARTH_RADIUS_METERS * c


def get_bounding_box(lat: float, lon: float, radius_meters: float) -> Tuple[float, float, float, float]:
    """
    Retorna uma caixa delimitadora (min_lat, max_lat, min_lon, max_lon)
    para pré-filtragem rápida no SQLite antes do cálculo exato de Haversine.
    """
    # 1 grau de latitude é aprox. 111.000 metros
    delta_lat = radius_meters / 111000.0
    
    # 1 grau de longitude varia com a latitude: 111.000 * cos(lat)
    cos_lat = math.cos(math.radians(lat))
    if abs(cos_lat) < 1e-6:
        delta_lon = 180.0
    else:
        delta_lon = radius_meters / (111000.0 * cos_lat)

    return (
        lat - delta_lat,
        lat + delta_lat,
        lon - delta_lon,
        lon + delta_lon,
    )
