
#include <stdio.h>
#include <math.h>

int main(void) {
    printf("sin_tab := [?]f32 {\n");
    for (int i = 0; i < 360; i++) {
	printf("    %f,\n", sin(i*0.0174533));
    }
    printf("}\n\n");
    printf("cos_tab := [?]f32 {\n");
    for (int i = 0; i < 360; i++) {
	printf("    %f,\n", cos(i*0.0174533));
    }
    printf("}\n");
}
