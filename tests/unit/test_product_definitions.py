import glob
import yaml
import os
import pytest

PRODUCT_DIR = 'products'


def _load_product(filename):
    path = os.path.join(PRODUCT_DIR, filename)
    assert os.path.exists(path), f"Product definition not found: {path}"
    with open(path, 'r') as f:
        return yaml.safe_load(f), path


def _assert_required_keys(product_def):
    assert 'name' in product_def, "Product name not defined"
    assert 'description' in product_def, "Product description not defined"
    assert 'metadata_type' in product_def, "Metadata type not defined"
    assert 'measurements' in product_def, "Measurements not defined"


def test_sentinel2_product_definition():
    product_def, _ = _load_product('s2_l2a.odc-product.yaml')
    _assert_required_keys(product_def)


def test_s2_geomad_annual_product_definition():
    product_def, _ = _load_product('s2_geomad_annual.odc-product.yaml')
    _assert_required_keys(product_def)

    assert product_def['name'] == 's2_geomad_annual'
    assert product_def['metadata_type'] == 'eo3'
    assert product_def['storage']['crs'] == 'EPSG:6933'
    assert product_def['storage']['resolution']['x'] == 10
    assert product_def['storage']['resolution']['y'] == -10

    expected_bands = [
        'blue', 'red', 'green', 'nir', 'nir08',
        'rededge1', 'rededge2', 'rededge3',
        'swir16', 'swir22', 'SMAD', 'EMAD', 'BCMAD', 'COUNT',
    ]
    actual_bands = [m['name'] for m in product_def['measurements']]
    assert actual_bands == expected_bands, f"Band mismatch: {actual_bands}"

    uint16_bands = {'blue', 'red', 'green', 'nir', 'nir08',
                    'rededge1', 'rededge2', 'rededge3',
                    'swir16', 'swir22', 'COUNT'}
    float32_bands = {'SMAD', 'EMAD', 'BCMAD'}

    for m in product_def['measurements']:
        if m['name'] in uint16_bands:
            assert m['dtype'] == 'uint16', f"{m['name']} should be uint16"
            assert m['nodata'] == 0, f"{m['name']} nodata should be 0"
        elif m['name'] in float32_bands:
            assert m['dtype'] == 'float32', f"{m['name']} should be float32"
            assert m['nodata'] == '.nan' or m['nodata'] is None or str(m['nodata']).lower() == 'nan', \
                f"{m['name']} nodata should be NaN"


def test_products_csv_has_s2_geomad_annual():
    csv_path = os.path.join('.', 'products.csv')
    assert os.path.exists(csv_path), "products.csv not found"

    with open(csv_path, 'r') as f:
        content = f.read()

    lines = [line.strip() for line in content.strip().splitlines() if line.strip()]
    found = False
    for line in lines:
        parts = line.split(',', 1)
        if len(parts) == 2 and parts[0] == 's2_geomad_annual':
            found = True
            assert 's2_geomad_annual.odc-product.yaml' in parts[1], \
                f"products.csv URL does not reference s2_geomad_annual.odc-product.yaml"
    assert found, "s2_geomad_annual not found in products.csv"


def test_all_product_yamls_are_valid():
    yaml_files = sorted(glob.glob(os.path.join(PRODUCT_DIR, '*.yaml')))
    assert len(yaml_files) > 0, "No product YAML files found"

    for yf in yaml_files:
        with open(yf, 'r') as f:
            docs = list(yaml.safe_load_all(f))
        for product_def in docs:
            _assert_required_keys(product_def)
            assert isinstance(product_def['measurements'], list)
            for m in product_def['measurements']:
                assert 'name' in m, f"Measurement missing 'name' in {yf}"
                assert 'dtype' in m, f"Measurement missing 'dtype' in {yf}"


def test_flood_hazard_product_definition():
    product_def, _ = _load_product('flood_hazard.odc-product.yaml')
    _assert_required_keys(product_def)

    assert product_def['name'] == 'flood_hazard'
    assert product_def['metadata_type'] == 'eo3'
    assert product_def['storage']['crs'] == 'EPSG:6933'
    assert product_def['storage']['resolution'] == {'x': 30, 'y': -30}

    return_periods = ['rp02', 'rp05', 'rp10', 'rp25', 'rp50']
    expected = [
        f'{variable}_{rp}'
        for rp in return_periods
        for variable in ('flood_depth', 'flood_hazard_index', 'flood_hazard_class')
    ]
    measurements = {m['name']: m for m in product_def['measurements']}
    assert list(measurements) == expected

    for name, m in measurements.items():
        if name.startswith('flood_hazard_class'):
            assert m['dtype'] == 'uint8'
            assert m['nodata'] == 255
            assert m['flags_definition']['hazard']['values'] == {1: 'low', 2: 'moderate', 3: 'high'}
        else:
            assert m['dtype'] == 'float32'
            assert str(m['nodata']).lower() == 'nan'


def test_products_csv_has_single_flood_hazard_product():
    with open('products.csv', 'r') as f:
        rows = [line.strip().split(',', 1) for line in f if line.strip()]
    flood_rows = [row for row in rows if row[0].startswith('flood_hazard')]
    assert flood_rows == [[
        'flood_hazard',
        'https://raw.githubusercontent.com/piksel-ina/inadc-odc/main/products/flood_hazard.odc-product.yaml',
    ]]
