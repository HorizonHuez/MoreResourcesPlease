shader_type canvas_item;

uniform float top_width : hint_range(0.0, 1.0) = 0.4;         // Ancho del texto/imagen en la parte superior (horizonte)
uniform float horizon_y : hint_range(0.0, 1.0) = 0.1;         // Posición vertical donde se ubica el "horizonte"
uniform float perspective_power : hint_range(0.1, 5.0) = 1.0; // Intensidad de la compresión vertical

void fragment() {
    vec2 uv = UV;
    
    // Si el píxel está por encima del horizonte definido, lo descartamos (transparente)
    if (uv.y < horizon_y) {
        discard;
    }
    
    // Normalizar la coordenada Y desde el horizonte (0.0) hasta la base (1.0)
    float t = (uv.y - horizon_y) / (1.0 - horizon_y);
    
    // Aplicar curva de perspectiva vertical (hace que se compriman más las líneas hacia arriba)
    t = pow(t, perspective_power);
    
    // Calcular el ancho actual: en el horizonte es 'top_width' y abajo es 1.0 (ancho completo)
    float current_width = mix(top_width, 1.0, t);
    
    // Centrar la transformación en el eje X (0.5 es el centro de la pantalla/textura)
    float new_x = (uv.x - 0.5) / current_width + 0.5;
    
    // Si el píxel sale de los bordes laterales tras la deformación, descartarlo
    if (new_x < 0.0 || new_x > 1.0) {
        discard;
    }
    
    // Muestrear la textura original con las coordenadas UV deformadas
    vec2 warped_uv = vec2(new_x, t);
    COLOR = texture(TEXTURE, warped_uv);
}