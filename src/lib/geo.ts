export function ubicacionActual() {
  return new Promise<{ lat: number; lng: number }>((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error('Este celular no entregó la ubicación.'))
      return
    }
    navigator.geolocation.getCurrentPosition(
      (posicion) => resolve({ lat: posicion.coords.latitude, lng: posicion.coords.longitude }),
      () => reject(new Error('Activa la ubicación solo para este registro. No se guarda un recorrido.')),
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 0 },
    )
  })
}
