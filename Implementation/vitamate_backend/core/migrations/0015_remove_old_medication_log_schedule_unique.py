from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0014_unified_medication_engine"),
    ]

    operations = [
        migrations.AlterUniqueTogether(
            name="conditionmedicationlog",
            unique_together=set(),
        ),
    ]

