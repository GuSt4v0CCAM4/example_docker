#!/bin/bash

# Etiquetar el segundo nodo como nodo de backend
kubectl label node $(kubectl get nodes | grep -v master | grep Ready | head -1 | awk '{print $1}') kubernetes.io/hostname=backend-node

# Etiquetar el tercer nodo como nodo de frontend
kubectl label node $(kubectl get nodes | grep -v master | grep Ready | tail -1 | awk '{print $1}') kubernetes.io/hostname=frontend-node

# Verificar las etiquetas
echo "Nodos etiquetados:"
kubectl get nodes --show-labels
