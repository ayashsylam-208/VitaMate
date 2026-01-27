from django.db import migrations


def seed_exercises(apps, schema_editor):
    Exercise = apps.get_model("core", "Exercise")
    items = [
        ("Walking (casual)", 3.0),
        ("Walking (brisk)", 4.3),
        ("Jogging", 7.0),
        ("Running 8 km/h", 8.3),
        ("Running 10 km/h", 10.0),
        ("Cycling (leisure)", 5.5),
        ("Cycling (moderate)", 7.5),
        ("Swimming (light)", 6.0),
        ("Swimming (vigorous)", 9.5),
        ("Jump rope", 12.3),
        ("HIIT (average)", 10.0),
        ("Bodyweight circuit", 8.0),
        ("Weight training", 6.0),
        ("Yoga", 3.0),
        ("Pilates", 3.5),
        ("Elliptical", 5.0),
        ("Stair climbing", 8.8),
        ("Rowing machine", 7.0),
        ("Dancing (aerobic)", 7.0),
        ("Football (casual)", 7.0),
        ("Basketball (game)", 8.0),
        ("Tennis", 7.3),
        ("Badminton", 5.5),
        ("Boxing (sparring)", 9.5),
        ("Martial arts", 10.0),
    ]
    for name, met in items:
        Exercise.objects.get_or_create(name=name, defaults={"met_value": met})


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0002_fooditem_upgrade'),
    ]

    operations = [
        migrations.RunPython(seed_exercises, migrations.RunPython.noop),
    ]

