from django.db import migrations


def drop_legacy_lab_percent_columns(apps, schema_editor):
    table_name = "core_usernutrienttarget"
    legacy_columns = {"lab_current_percent", "lab_target_percent"}
    connection = schema_editor.connection
    with connection.cursor() as cursor:
        existing_columns = {
            column.name
            for column in connection.introspection.get_table_description(
                cursor,
                table_name,
            )
        }
    for column_name in legacy_columns.intersection(existing_columns):
        schema_editor.execute(
            schema_editor.sql_delete_column
            % {
                "table": schema_editor.quote_name(table_name),
                "column": schema_editor.quote_name(column_name),
            }
        )


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0023_usernutrienttarget_lab_context"),
    ]

    operations = [
        migrations.RunPython(
            drop_legacy_lab_percent_columns,
            reverse_code=migrations.RunPython.noop,
        ),
    ]
