<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class HealthController extends Controller
{
    /**
     * Check the health of the application.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function check(): JsonResponse
    {
        $status = 'ok';
        $checks = [
            'app' => true,
            'database' => $this->checkDatabase(),
        ];

        // Si alguna comprobación falla, cambiamos el estado general
        if (in_array(false, $checks, true)) {
            $status = 'error';
        }

        return response()->json([
            'status' => $status,
            'timestamp' => now()->toIso8601String(),
            'checks' => $checks,
        ]);
    }

    /**
     * Check the database connection.
     *
     * @return bool
     */
    private function checkDatabase(): bool
    {
        try {
            // Intentamos hacer una consulta simple a la base de datos
            DB::select('SELECT 1');
            return true;
        } catch (\Exception $e) {
            return false;
        }
    }
}
