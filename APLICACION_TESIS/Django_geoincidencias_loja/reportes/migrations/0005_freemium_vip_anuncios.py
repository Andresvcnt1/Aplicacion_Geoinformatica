from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('reportes', '0004_historialestado_fecha_ultima_actualizacion'),
    ]

    operations = [
        migrations.AddField(
            model_name='usuario',
            name='vip_hasta',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='incidencia',
            name='anonimo',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='incidencia',
            name='prioritaria',
            field=models.BooleanField(default=False),
        ),
        migrations.CreateModel(
            name='Anuncio',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('anunciante', models.CharField(max_length=100)),
                ('titulo', models.CharField(max_length=120)),
                ('texto', models.CharField(blank=True, default='', max_length=240)),
                ('imagen', models.ImageField(blank=True, null=True, upload_to='anuncios/')),
                ('enlace', models.URLField(blank=True, default='')),
                ('activo', models.BooleanField(default=True)),
                ('orden', models.PositiveIntegerField(default=0)),
            ],
            options={
                'ordering': ['orden', '-id'],
            },
        ),
    ]