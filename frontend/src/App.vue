<script setup>
// App.vue utiliza el router configurado
</script>

<template>
  <div class="app">
    <header class="app-header">
      <div class="container">
        <h1>Sistema de Registro</h1>
      </div>
    </header>

    <main class="container">
      <RouterView />
    </main>

    <footer class="app-footer">
      <div class="container">
        <p>&copy; {{ new Date().getFullYear() }} - Sistema de Registro de Personas</p>
      </div>
    </footer>
  </div>
</template>

<style>
/* Estilos globales */
:root {
  --primary-color: #3182ce;
  --secondary-color: #2c3e50;
  --light-color: #f8fafc;
  --border-color: #e2e8f0;
  --text-color: #4a5568;
  --text-light: #718096;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  line-height: 1.6;
  color: var(--text-color);
  background-color: #f8fafc;
}

.container {
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 1rem;
}

/* Estilos específicos */
.app {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

.app-header {
  background-color: var(--primary-color);
  color: white;
  padding: 1rem 0;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.app-header h1 {
  font-size: 1.5rem;
}

main {
  flex: 1;
  padding: 2rem 0;
}

.app-footer {
  background-color: var(--secondary-color);
  color: white;
  padding: 1rem 0;
  text-align: center;
  margin-top: auto;
}

/* Estilos responsivos */
@media (max-width: 768px) {
  .app-header h1 {
    font-size: 1.25rem;
  }
}
</style>
