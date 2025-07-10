from core_users.managers import CustomUserManager
from datetime import timezone
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils import timezone

# Create your models here.


class CustomUser(AbstractUser):
    """
    The custom user authentication model,created once the registration session
    model has email and phone verified.

    Model Fields:
        - email
        - phone
        - first_name
        - last_name
        - username : over-ride to none
        - is_admitted
        - admission_date
        - created_on
        - updated_on
        - is_active
    """

    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=10, unique=True)

    first_name = models.CharField(max_length=30)
    last_name = models.CharField(max_length=30)

    username = None

    is_admitted = models.BooleanField(default=False)
    admission_date = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    is_active = models.BooleanField(default=True)

    objects = CustomUserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['phone']

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.first_name} {self.last_name} : {self.email}"


class RegistrationSession(models.Model):
    """
    Registration Service Model. Helps users to continue their pending user registration flow
    even after they reopen the website / app.
    Registration Sessions will have an expiry time of 24hrs (can be changed from .env)

    Model Fields:
        - email
        - phone
        - first_name
        - last_name
        - is_email_verified
        - is_phone_verified
    """

    email = models.EmailField()
    phone = models.CharField(max_length=10)

    first_name = models.CharField(max_length=30)
    last_name = models.CharField(max_length=30)

    is_email_verified = models.BooleanField(default=False)
    is_phone_verified = models.BooleanField(default=False)

    expires_at = models.DateTimeField()

    def __str__(self):
        return f"Registration Session for {self.email} - {self.phone}"

    def is_expired(self):
        return timezone.now()>self.expires_at
