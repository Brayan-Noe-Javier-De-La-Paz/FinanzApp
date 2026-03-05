# Usamos el repositorio oficial, público y actualizado de Flutter (cirruslabs)
FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

# Copiamos todo (asegúrate de que tu archivo .dockerignore siga ahí)
COPY . .

# Descargamos las dependencias de tu proyecto
RUN flutter pub get

# Ejecutamos las pruebas
CMD ["flutter", "test"]