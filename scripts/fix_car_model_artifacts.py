"""CMA01-CMA04: reuse the qualified five-car pipeline with private task evidence."""
import sys
import run_car_model_artifacts  # Establish task paths before loading producers.

if '--refresh' in sys.argv or '--pictures' in sys.argv:
    import refresh_car_10k_assets as producer
else:
    import bake_car_10k as producer

if __name__=='__main__':
    if '--install' in sys.argv:
        import json
        producer.publish(json.loads((producer.OUT/'plan.json').read_text()))
    else:
        producer.main()
