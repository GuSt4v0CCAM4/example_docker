<?php

namespace App\Http\Controllers;

use App\Models\Person;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class PersonController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $people = Person::all();
        return response()->json(["data" => $people]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $validatedData = $request->validate([
            "nombre" => "required|string|max:255",
            "apellido" => "required|string|max:255",
            "telefono" => "required|string|max:20",
            "dni" => "required|string|unique:people,dni|max:20",
        ]);

        $person = Person::create($validatedData);

        return response()->json(
            [
                "message" => "Persona registrada correctamente",
                "data" => $person,
            ],
            201,
        );
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        //
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        //
    }
}
