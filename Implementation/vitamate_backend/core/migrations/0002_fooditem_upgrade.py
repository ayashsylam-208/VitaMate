from django.db import migrations, models


def seed_fooditems(apps, schema_editor):
    FoodItem = apps.get_model("core", "FoodItem")
    items = [
        # Arabic / Middle Eastern
        ("Hummus", 166, 8, 14, 9, "Bowl", 180),
        ("Falafel", 333, 13, 31, 17, "Portion", 120),
        ("Chicken Shawarma", 215, 25, 5, 10, "Wrap", 180),
        ("Beef Shawarma", 250, 20, 5, 15, "Wrap", 180),
        ("Kabsa (chicken)", 185, 10, 22, 6, "Plate", 250),
        ("Kabsa (meat)", 210, 12, 23, 8, "Plate", 250),
        ("Mansaf", 200, 11, 19, 9, "Plate", 260),
        ("Maqluba", 170, 8, 25, 5, "Plate", 260),
        ("Kebab", 250, 20, 2, 18, "Skewer", 120),
        ("Kofta", 260, 18, 3, 20, "Portion", 150),
        ("Tabbouleh", 75, 3, 12, 3, "Bowl", 150),
        ("Fattoush", 90, 2, 12, 4, "Bowl", 170),
        ("Baba Ghanoush", 120, 3, 10, 8, "Bowl", 150),
        ("Mujadara", 180, 8, 30, 3, "Plate", 220),
        ("Lentil Soup", 110, 7, 17, 2, "Bowl", 220),
        ("Labneh", 150, 10, 5, 10, "Bowl", 120),
        ("Shakshuka", 130, 8, 7, 8, "Skillet", 200),
        ("Foul Medames", 110, 8, 18, 1, "Bowl", 200),
        ("Cheese Sambousek", 320, 9, 25, 20, "Piece", 80),
        ("Manakish Zaatar", 280, 9, 32, 12, "Round", 200),
        ("Manakish Cheese", 300, 12, 30, 14, "Round", 200),
        ("Warak Enab", 160, 4, 22, 6, "Plate", 220),
        ("Kabab Hindi", 210, 16, 8, 12, "Plate", 220),
        ("Dawood Basha", 230, 15, 10, 14, "Plate", 220),
        ("Baked Kibbeh", 190, 12, 18, 8, "Slice", 150),
        # International
        ("Grilled Chicken Breast", 165, 31, 0, 4, "Portion", 180),
        ("Beef Steak", 250, 26, 0, 15, "Portion", 200),
        ("Grilled Salmon", 208, 20, 0, 13, "Fillet", 170),
        ("Tuna (canned)", 132, 28, 0, 1, "Can", 120),
        ("Pasta Marinara", 150, 5, 28, 2, "Plate", 220),
        ("Pasta Alfredo", 220, 7, 25, 10, "Plate", 220),
        ("Caesar Salad", 180, 7, 8, 14, "Bowl", 200),
        ("Greek Salad", 120, 4, 8, 8, "Bowl", 200),
        ("Beef Burger", 260, 16, 22, 12, "Sandwich", 200),
        ("Pizza Margherita", 230, 9, 28, 9, "Slice", 140),
        ("Salmon Sushi Roll", 145, 7, 23, 3, "Roll", 150),
        ("Oatmeal with Milk", 120, 5, 20, 3, "Bowl", 200),
        ("Fried Rice", 180, 4, 32, 4, "Plate", 220),
        ("Chicken Curry", 190, 16, 8, 10, "Plate", 220),
        ("Beef Chili", 180, 14, 14, 8, "Bowl", 220),
        ("Roast Potatoes", 150, 3, 28, 3, "Plate", 200),
        ("Mashed Potatoes", 110, 2, 20, 3, "Bowl", 200),
        ("Cooked Quinoa", 120, 4, 21, 2, "Bowl", 180),
        ("Avocado Toast", 220, 6, 22, 12, "Slice", 120),
        ("Pancakes", 220, 6, 35, 6, "Stack", 180),
        ("Veggie Omelette", 150, 11, 4, 10, "Skillet", 180),
        ("Plain Yogurt", 60, 3, 5, 3, "Cup", 150),
        ("Apple", 52, 0, 14, 0, "Piece", 150),
        ("Banana", 89, 1, 23, 0, "Piece", 120),
        ("Mixed Nuts", 607, 20, 21, 54, "Handful", 30),
    ]
    for name, cal, p, c, f, label, grams in items:
        FoodItem.objects.get_or_create(
            name=name,
            defaults=dict(
                calories_100g=cal,
                protein_100g=p,
                carbs_100g=c,
                fat_100g=f,
                serving_label=label,
                serving_grams=grams,
            ),
        )


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0001_initial'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='fooditem',
            name='calories',
        ),
        migrations.RemoveField(
            model_name='fooditem',
            name='protein',
        ),
        migrations.RemoveField(
            model_name='fooditem',
            name='carbs',
        ),
        migrations.RemoveField(
            model_name='fooditem',
            name='fat',
        ),
        migrations.AddField(
            model_name='fooditem',
            name='calories_100g',
            field=models.IntegerField(default=0),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='fooditem',
            name='carbs_100g',
            field=models.FloatField(default=0),
        ),
        migrations.AddField(
            model_name='fooditem',
            name='fat_100g',
            field=models.FloatField(default=0),
        ),
        migrations.AddField(
            model_name='fooditem',
            name='protein_100g',
            field=models.FloatField(default=0),
        ),
        migrations.AddField(
            model_name='fooditem',
            name='serving_grams',
            field=models.IntegerField(default=250),
        ),
        migrations.AddField(
            model_name='fooditem',
            name='serving_label',
            field=models.CharField(default='Plate', max_length=50),
        ),
        migrations.RemoveField(
            model_name='meallog',
            name='quantity',
        ),
        migrations.AddField(
            model_name='meallog',
            name='quantity_grams',
            field=models.FloatField(default=100.0, help_text='Quantity in grams'),
        ),
        migrations.RunPython(seed_fooditems, migrations.RunPython.noop),
    ]

