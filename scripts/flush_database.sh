echo "Resetting Database..."

python manage.py flush --no-input

echo "Database has been reset successfully!"

echo "Creating Admin User..."

python manage.py shell <<EOF
from core_users.models import CustomUser

email = "admin@email.com"
phone = "0000000000"
password = "test@123"

if not CustomUser.objects.filter(email=email).exists():
    admin = CustomUser.objects.create(
        email=email,
        phone=phone,
        first_name='admin',
        last_name='user',
        is_staff=True,
        is_superuser=True
    )
    admin.set_password(password)
    admin.save()
    print("Admin user created.")
else:
    print("Admin user already exists.")
EOF

echo "email    : admin@email.com"
echo "phone    : 00000 00000"
echo "password : test@123"