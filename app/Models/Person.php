<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Person extends Model
{
    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = ["nombre", "apellido", "telefono", "dni"];

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = "people";
}
