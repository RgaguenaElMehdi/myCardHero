shader_type canvas_item;
// Balancement de bannière : le haut reste accroché (UV.y=0), le bas oscille.
// Déplacement des sommets du quad -> aucun besoin de subdivision.
uniform float amplitude = 3.5;
uniform float speed = 1.6;
uniform float phase = 0.0;

void vertex() {
	VERTEX.x += (sin(TIME * speed + phase)
			+ 0.4 * sin(TIME * speed * 2.7 + phase * 1.3)) * amplitude * UV.y;
}
