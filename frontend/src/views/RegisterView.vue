<script setup>
import { ref, onMounted } from 'vue'

// Estado del formulario
const form = ref({
  nombre: '',
  apellido: '',
  telefono: '',
  dni: ''
})

// Estado de errores
const errors = ref({})
// Estado para guardar la lista de personas
const people = ref([])
// Estado para manejar el estado de envío
const isSubmitting = ref(false)
// Estado para manejar mensajes de éxito
const successMessage = ref('')

// Cargar la lista de personas al montar el componente
onMounted(async () => {
  await fetchPeople()
})

// Función para obtener la lista de personas
const fetchPeople = async () => {
  try {
    const response = await fetch('/api/people')
    const result = await response.json()
    people.value = result.data
  } catch (error) {
    console.error('Error al cargar las personas:', error)
  }
}

// Función para enviar el formulario
const submitForm = async () => {
  isSubmitting.value = true
  errors.value = {}

  try {
    const response = await fetch('/api/people', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(form.value)
    })

    const result = await response.json()

    if (response.ok) {
      successMessage.value = result.message || 'Registro exitoso'
      // Limpiar el formulario
      form.value = {
        nombre: '',
        apellido: '',
        telefono: '',
        dni: ''
      }
      // Actualizar la lista de personas
      await fetchPeople()
    } else {
      // Manejar errores de validación
      if (result.errors) {
        errors.value = result.errors
      }
    }
  } catch (error) {
    console.error('Error al enviar el formulario:', error)
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="register-container">
    <div class="register-card">
      <h1 class="register-title">Registro de Personas</h1>

      <!-- Mensaje de éxito -->
      <div v-if="successMessage" class="success-message">
        {{ successMessage }}
      </div>

      <!-- Formulario de registro -->
      <form @submit.prevent="submitForm" class="register-form">
        <div class="form-group">
          <label for="nombre">Nombre</label>
          <input
            id="nombre"
            v-model="form.nombre"
            type="text"
            class="form-control"
            :class="{ 'is-invalid': errors.nombre }"
            required
          >
          <div v-if="errors.nombre" class="error-message">{{ errors.nombre[0] }}</div>
        </div>

        <div class="form-group">
          <label for="apellido">Apellido</label>
          <input
            id="apellido"
            v-model="form.apellido"
            type="text"
            class="form-control"
            :class="{ 'is-invalid': errors.apellido }"
            required
          >
          <div v-if="errors.apellido" class="error-message">{{ errors.apellido[0] }}</div>
        </div>

        <div class="form-group">
          <label for="telefono">Teléfono</label>
          <input
            id="telefono"
            v-model="form.telefono"
            type="tel"
            class="form-control"
            :class="{ 'is-invalid': errors.telefono }"
            required
          >
          <div v-if="errors.telefono" class="error-message">{{ errors.telefono[0] }}</div>
        </div>

        <div class="form-group">
          <label for="dni">DNI</label>
          <input
            id="dni"
            v-model="form.dni"
            type="text"
            class="form-control"
            :class="{ 'is-invalid': errors.dni }"
            required
          >
          <div v-if="errors.dni" class="error-message">{{ errors.dni[0] }}</div>
        </div>

        <button
          type="submit"
          class="submit-button"
          :disabled="isSubmitting"
        >
          {{ isSubmitting ? 'Enviando...' : 'Registrar' }}
        </button>
      </form>
    </div>

    <!-- Tabla de personas registradas -->
    <div class="people-table-container">
      <h2 class="table-title">Personas Registradas</h2>

      <table v-if="people.length > 0" class="people-table">
        <thead>
          <tr>
            <th>Nombre</th>
            <th>Apellido</th>
            <th>Teléfono</th>
            <th>DNI</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="person in people" :key="person.id">
            <td>{{ person.nombre }}</td>
            <td>{{ person.apellido }}</td>
            <td>{{ person.telefono }}</td>
            <td>{{ person.dni }}</td>
          </tr>
        </tbody>
      </table>

      <div v-else class="no-data-message">
        No hay personas registradas todavía.
      </div>
    </div>
  </div>
</template>

<style scoped>
.register-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
}

.register-card {
  background-color: #ffffff;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  padding: 2rem;
  margin-bottom: 2rem;
}

.register-title {
  color: #2c3e50;
  font-size: 1.8rem;
  margin-bottom: 1.5rem;
  text-align: center;
}

.register-form {
  display: grid;
  gap: 1.5rem;
}

.form-group {
  display: flex;
  flex-direction: column;
}

label {
  font-weight: 600;
  margin-bottom: 0.5rem;
  color: #4a5568;
}

.form-control {
  padding: 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  font-size: 1rem;
  transition: border-color 0.2s ease;
}

.form-control:focus {
  outline: none;
  border-color: #4299e1;
  box-shadow: 0 0 0 3px rgba(66, 153, 225, 0.15);
}

.is-invalid {
  border-color: #e53e3e;
}

.error-message {
  color: #e53e3e;
  font-size: 0.875rem;
  margin-top: 0.25rem;
}

.success-message {
  background-color: #c6f6d5;
  color: #2f855a;
  padding: 0.75rem;
  border-radius: 4px;
  margin-bottom: 1.5rem;
  text-align: center;
}

.submit-button {
  padding: 0.75rem 1.5rem;
  background-color: #3182ce;
  color: white;
  font-weight: 600;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.2s ease;
}

.submit-button:hover {
  background-color: #2b6cb0;
}

.submit-button:disabled {
  background-color: #a0aec0;
  cursor: not-allowed;
}

.people-table-container {
  background-color: #ffffff;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  padding: 2rem;
}

.table-title {
  color: #2c3e50;
  font-size: 1.5rem;
  margin-bottom: 1.5rem;
  text-align: center;
}

.people-table {
  width: 100%;
  border-collapse: collapse;
}

.people-table th,
.people-table td {
  padding: 0.75rem 1rem;
  text-align: left;
  border-bottom: 1px solid #e2e8f0;
}

.people-table th {
  background-color: #f7fafc;
  font-weight: 600;
}

.people-table tr:hover {
  background-color: #f7fafc;
}

.no-data-message {
  text-align: center;
  color: #718096;
  padding: 2rem 0;
}

/* Diseño responsivo */
@media (max-width: 768px) {
  .register-form {
    gap: 1rem;
  }

  .form-control {
    padding: 0.5rem;
  }

  .people-table th,
  .people-table td {
    padding: 0.5rem;
    font-size: 0.875rem;
  }
}
</style>
