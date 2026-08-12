-- =============================================================================
-- Migración: Catálogo real de servicios (19 servicios, 3 categorías).
-- -----------------------------------------------------------------------------
-- Importa el catálogo definitivo extraído de SERVICIOS.xlsx. Idempotente:
-- solo inserta lo que no exista por nombre (WHERE NOT EXISTS), sin tocar
-- filas ya presentes ni cambiar sus flags/precios.
-- =============================================================================

-- 1. Categorías ----------------------------------------------------------------
INSERT INTO public.categorias_servicio (nombre, descripcion, activo)
SELECT v.nombre, v.descripcion, v.activo
FROM (VALUES
    ('Inyectables', 'Tratamientos inyectables de armonización y rejuvenecimiento facial.', true),
    ('Faciales y Piel', 'Tratamientos faciales y de cuidado de la piel.', true),
    ('Contorno Corporal', 'Tratamientos de remodelación y contorno corporal.', true)
) AS v(nombre, descripcion, activo)
WHERE NOT EXISTS (
    SELECT 1 FROM public.categorias_servicio c WHERE lower(c.nombre) = lower(v.nombre)
);

-- 2. Servicios ----------------------------------------------------------------
INSERT INTO public.servicios (
    categoria_id, nombre, descripcion, precio_base, tipo_precio,
    requiere_face_map, activo
)
SELECT
    (SELECT id FROM public.categorias_servicio WHERE lower(nombre) = lower(v.cat)),
    v.nombre, v.descripcion, v.precio, v.tipo::public.tipo_precio_enum, v.face_map, true
FROM (VALUES
    -- inyectables
    ('Inyectables', 'Relleno de Labios con Ácido Hialurónico',
     'El relleno de labios con ácido hialurónico es un tratamiento estético no quirúrgico que permite aumentar volumen, mejorar la forma, definir el contorno e hidratar profundamente los labios. El ácido hialurónico es una sustancia biocompatible y segura que se encuentra de forma natural en el cuerpo, lo que garantiza resultados armoniosos y naturales.',
     450.00, 'PRECIO_FIJO', true),
    ('Inyectables', 'Botox (Toxina Botulínica)',
     'El Botox es un tratamiento médico-estético que relaja de forma temporal los músculos responsables de las líneas de expresión. Se utiliza para suavizar arrugas dinámicas como las del entrecejo, frente y patas de gallo, logrando un rostro más descansado y rejuvenecido sin perder naturalidad.',
     9.95, 'POR_UNIDAD', true),
    ('Inyectables', 'Rejuvenecimiento con Ácido Hialurónico',
     'El ácido hialurónico es una sustancia biocompatible que se encuentra de forma natural en nuestro cuerpo. En estética se utiliza para restaurar volumen, definir contornos faciales, hidratar la piel y suavizar surcos.',
     450.00, 'PRECIO_FIJO', true),
    ('Inyectables', 'Sculptra',
     'Sculptra es un bioestimulador a base de ácido poli-L-láctico que estimula la producción natural de colágeno. A diferencia de los rellenos tradicionales, su efecto es progresivo y de larga duración.',
     600.00, 'PRECIO_FIJO', true),
    ('Inyectables', 'Hilos Tensores',
     'Los hilos tensores son filamentos biocompatibles que se colocan bajo la piel para tensar, redefinir y estimular colágeno, logrando un efecto lifting sin cirugía.',
     350.00, 'PRECIO_FIJO', true),
    ('Inyectables', 'Rinomodelación con Ácido Hialurónico',
     'La rinomodelación con ácido hialurónico es un procedimiento no quirúrgico que permite mejorar la forma y proporciones de la nariz de manera segura y rápida. A través de microinyecciones estratégicas de ácido hialurónico se corrigen irregularidades, levanta la punta, suaviza jorobas o armoniza el perfil facial sin cirugía.',
     450.00, 'PRECIO_FIJO', true),
    ('Inyectables', 'Hidrolipoclasia en Papada',
     'La hidrolipoclasia es un procedimiento estético no quirúrgico diseñado para reducir la grasa localizada en la papada, afinando y redefiniendo el contorno del rostro. Mediante la aplicación de microinyecciones con soluciones específicas se provoca la ruptura de las células grasas, facilitando su eliminación natural.',
     145.00, 'POR_SESION', true),
    ('Inyectables', 'Full Face con Ácido Hialurónico',
     'El tratamiento Full Face con ácido hialurónico busca armonizar y rejuvenecer todo el rostro de manera integral. Mediante microinyecciones estratégicas se restaura volumen perdido en pómulos, mejillas y mentón, se suavizan líneas de expresión y arrugas, y se mejora el contorno facial y la simetría.',
     1995.00, 'PRECIO_FIJO', true),
    ('Inyectables', 'PDRN de Salmón (Rejuvenecimiento Regenerativo)',
     'El PDRN de salmón (Polideoxirribonucleótidos) es un tratamiento avanzado de bioestimulación celular que promueve la regeneración, reparación y rejuvenecimiento de la piel desde el interior. Derivado del ADN del salmón purificado, estimula la producción de colágeno, mejora la elasticidad y la calidad general de la piel.',
     450.00, 'POR_SESION', true),
    ('Inyectables', 'Exosomas (Regeneración Celular Avanzada)',
     'El tratamiento con exosomas es una terapia regenerativa de última generación que estimula la reparación celular y el rejuvenecimiento profundo de la piel. Los exosomas actúan como mensajeros biológicos que activan la producción de colágeno, mejoran la elasticidad y favorecen la renovación celular.',
     450.00, 'POR_SESION', true),

    -- faciales y piel
    ('Faciales y Piel', 'Fibroblast (Plasma Pen)',
     'El Fibroblast, también conocido como Plasma Pen, es un tratamiento estético no quirúrgico que utiliza energía de plasma para estimular la producción natural de colágeno y elastina. Está diseñado para reafirmar la piel, reducir arrugas, mejorar flacidez y rejuvenecer áreas específicas sin necesidad de cirugía.',
     250.00, 'PRECIO_FIJO', true),
    ('Faciales y Piel', 'Desintoxicación Facial Profunda Carelika Skin Care',
     'La Desintoxicación Facial Profunda con Carelika Skin Care es un tratamiento integral que combina técnicas avanzadas para purificar y revitalizar la piel. Utiliza extracción de puntos negros, microdermoabrasión, paleta ultrasónica, luz LED, ozono y productos especializados para una desintoxicación completa.',
     180.00, 'PRECIO_FIJO', true),
    ('Faciales y Piel', 'Microneedling (Inducción de Colágeno)',
     'El microneedling es un tratamiento mínimamente invasivo que estimula la regeneración natural de la piel mediante microperforaciones controladas. Este proceso activa la producción de colágeno y elastina, mejorando la textura, firmeza y apariencia general de la piel.',
     250.00, 'PRECIO_FIJO', true),

    -- contorno corporal
    ('Contorno Corporal', 'Cauterización de Lunares y Skin Tags (Acrocordones)',
     'La cauterización de lunares benignos y skin tags (acrocordones) es un procedimiento estético no quirúrgico que utiliza tecnología especializada para eliminar de forma segura lesiones cutáneas superficiales, mejorando la apariencia de la piel y devolviendo uniformidad al área tratada.',
     25.00, 'POR_UNIDAD', false),
    ('Contorno Corporal', 'Cavitación Corporal Ultrasónica',
     'La cavitación corporal es un tratamiento estético no invasivo que utiliza ultrasonido de baja frecuencia para romper las células grasas localizadas, facilitando su eliminación natural a través del sistema linfático. Es una excelente alternativa para moldear el cuerpo sin cirugía.',
     80.00, 'PRECIO_FIJO', false),
    ('Contorno Corporal', 'Radiofrecuencia Facial y Corporal',
     'La radiofrecuencia es un tratamiento estético no invasivo que utiliza energía térmica controlada para estimular la producción natural de colágeno y elastina, mejorar la firmeza de la piel y redefinir el contorno facial y corporal.',
     80.00, 'PRECIO_FIJO', false),
    ('Contorno Corporal', 'Ultrasonido Estético Facial y Corporal',
     'El ultrasonido estético es un tratamiento no invasivo que utiliza ondas ultrasónicas de alta frecuencia para estimular la circulación, mejorar la penetración de activos, favorecer la reducción de grasa localizada y promover la reafirmación de la piel.',
     80.00, 'PRECIO_FIJO', false),
    ('Contorno Corporal', 'Drenaje Linfático Facial y Corporal',
     'El drenaje linfático es una técnica terapéutica manual o asistida que estimula el sistema linfático para eliminar toxinas, reducir inflamación, mejorar la circulación y favorecer la desintoxicación natural del cuerpo.',
     80.00, 'PRECIO_FIJO', false),
    ('Contorno Corporal', 'Postoperatorio de Cirugía Plástica',
     'El tratamiento postoperatorio de cirugía plástica es un protocolo especializado diseñado para acelerar la recuperación, reducir inflamación, prevenir fibrosis y optimizar los resultados estéticos después de procedimientos quirúrgicos como liposucción, abdominoplastia, lipoescultura, BBL, aumento mamario y lifting.',
     120.00, 'PRECIO_FIJO', false)
) AS v(cat, nombre, descripcion, precio, tipo, face_map)
WHERE NOT EXISTS (
    SELECT 1 FROM public.servicios s WHERE lower(s.nombre) = lower(v.nombre)
);
