import '../../catalog/domain/product.dart';
import '../domain/portal_models.dart';

/// Plantillas de atributos del mock: las mismas de la migración del catálogo
/// (`attribute_definitions`), para usar el portal sin backend.
const mockAttributeTemplates = <ProductCategory, List<AttributeDefinition>>{
  ProductCategory.cpu: [
    AttributeDefinition(key: 'socket', label: 'Socket', type: AttributeType.choice, isRequired: true,
        allowedValues: ['AM4', 'AM5', 'LGA1700', 'LGA1851']),
    AttributeDefinition(key: 'cores', label: 'Núcleos', type: AttributeType.number, isRequired: true),
    AttributeDefinition(key: 'threads', label: 'Hilos', type: AttributeType.number),
    AttributeDefinition(key: 'base_clock_ghz', label: 'Frecuencia base', type: AttributeType.number, unit: 'GHz'),
    AttributeDefinition(key: 'boost_clock_ghz', label: 'Frecuencia turbo', type: AttributeType.number, unit: 'GHz'),
    AttributeDefinition(key: 'tdp_w', label: 'Consumo (TDP)', type: AttributeType.number, unit: 'W', isRequired: true),
    AttributeDefinition(key: 'integrated_graphics', label: 'Gráficos integrados', type: AttributeType.boolean),
  ],
  ProductCategory.motherboard: [
    AttributeDefinition(key: 'socket', label: 'Socket', type: AttributeType.choice, isRequired: true,
        allowedValues: ['AM4', 'AM5', 'LGA1700', 'LGA1851']),
    AttributeDefinition(key: 'chipset', label: 'Chipset', type: AttributeType.text, isRequired: true),
    AttributeDefinition(key: 'form_factor', label: 'Formato', type: AttributeType.choice, isRequired: true,
        allowedValues: ['EATX', 'ATX', 'microATX', 'miniITX']),
    AttributeDefinition(key: 'ram_type', label: 'Tipo de memoria', type: AttributeType.choice, isRequired: true,
        allowedValues: ['DDR4', 'DDR5']),
    AttributeDefinition(key: 'ram_slots', label: 'Ranuras de memoria', type: AttributeType.number, isRequired: true),
    AttributeDefinition(key: 'max_ram_gb', label: 'Memoria máxima', type: AttributeType.number, unit: 'GB'),
    AttributeDefinition(key: 'm2_slots', label: 'Ranuras M.2', type: AttributeType.number),
  ],
  ProductCategory.ram: [
    AttributeDefinition(key: 'ram_type', label: 'Tipo de memoria', type: AttributeType.choice, isRequired: true,
        allowedValues: ['DDR4', 'DDR5']),
    AttributeDefinition(key: 'capacity_gb', label: 'Capacidad total del kit', type: AttributeType.number, unit: 'GB',
        isRequired: true),
    AttributeDefinition(key: 'modules', label: 'Módulos', type: AttributeType.number, isRequired: true),
    AttributeDefinition(key: 'speed_mts', label: 'Velocidad', type: AttributeType.number, unit: 'MT/s', isRequired: true),
  ],
  ProductCategory.gpu: [
    AttributeDefinition(key: 'chipset', label: 'Chip gráfico', type: AttributeType.text, isRequired: true),
    AttributeDefinition(key: 'vram_gb', label: 'Memoria de video', type: AttributeType.number, unit: 'GB', isRequired: true),
    AttributeDefinition(key: 'tdp_w', label: 'Consumo (TDP)', type: AttributeType.number, unit: 'W', isRequired: true),
    AttributeDefinition(key: 'length_mm', label: 'Largo', type: AttributeType.number, unit: 'mm', isRequired: true),
    AttributeDefinition(key: 'recommended_psu_w', label: 'Fuente recomendada', type: AttributeType.number, unit: 'W'),
  ],
  ProductCategory.storage: [
    AttributeDefinition(key: 'storage_type', label: 'Tipo', type: AttributeType.choice, isRequired: true,
        allowedValues: ['NVMe', 'SATA_SSD', 'HDD']),
    AttributeDefinition(key: 'capacity_gb', label: 'Capacidad', type: AttributeType.number, unit: 'GB', isRequired: true),
    AttributeDefinition(key: 'interface', label: 'Interfaz', type: AttributeType.choice, isRequired: true,
        allowedValues: ['PCIe5', 'PCIe4', 'PCIe3', 'SATA']),
  ],
  ProductCategory.psu: [
    AttributeDefinition(key: 'wattage_w', label: 'Potencia', type: AttributeType.number, unit: 'W', isRequired: true),
    AttributeDefinition(key: 'efficiency', label: 'Certificación', type: AttributeType.choice,
        allowedValues: ['80PLUS', 'BRONZE', 'GOLD', 'PLATINUM', 'TITANIUM']),
    AttributeDefinition(key: 'modularity', label: 'Modularidad', type: AttributeType.choice,
        allowedValues: ['full', 'semi', 'none']),
  ],
  ProductCategory.pcCase: [
    AttributeDefinition(key: 'supported_form_factors', label: 'Formatos de placa admitidos', type: AttributeType.choices,
        isRequired: true, allowedValues: ['EATX', 'ATX', 'microATX', 'miniITX']),
    AttributeDefinition(key: 'max_gpu_length_mm', label: 'Largo máximo de gráfica', type: AttributeType.number, unit: 'mm',
        isRequired: true),
    AttributeDefinition(key: 'max_cooler_height_mm', label: 'Altura máxima de disipador', type: AttributeType.number,
        unit: 'mm'),
    AttributeDefinition(key: 'radiator_support_mm', label: 'Radiadores admitidos', type: AttributeType.choices,
        allowedValues: ['120', '240', '280', '360', '420']),
  ],
  ProductCategory.cooling: [
    AttributeDefinition(key: 'cooling_type', label: 'Tipo', type: AttributeType.choice, isRequired: true,
        allowedValues: ['air', 'liquid']),
    AttributeDefinition(key: 'supported_sockets', label: 'Sockets admitidos', type: AttributeType.choices, isRequired: true,
        allowedValues: ['AM4', 'AM5', 'LGA1700', 'LGA1851']),
    AttributeDefinition(key: 'radiator_mm', label: 'Tamaño de radiador', type: AttributeType.number, unit: 'mm'),
    AttributeDefinition(key: 'height_mm', label: 'Altura', type: AttributeType.number, unit: 'mm'),
    AttributeDefinition(key: 'tdp_rating_w', label: 'Disipación máxima', type: AttributeType.number, unit: 'W'),
  ],
};
