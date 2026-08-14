precision mediump float;

varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec4 c = texture2D(tex, v_texcoord);
    float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    gl_FragColor = vec4(gray, gray, gray, c.a);
}
