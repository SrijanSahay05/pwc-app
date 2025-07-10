from django.contrib.auth.models import BaseUserManager

"""This wasn't implemented anywehere in the codebase"""


class CustomUserManager(BaseUserManager):
    """Custom Manager for AuthUser model."""

    def create_user(self, email, phone_number, password=None, **extra_fields):
        """
        Create and return a user with an email, phone number and password.
        """
        if not email:
            raise ValueError("The Email field must be set")
        if not phone_number:
            raise ValueError("The Phone Number field must be set")

        email = self.normalize_email(email)
        user = self.model(email=email, phone_number=phone_number, **extra_fields)
        if password:
            user.set_password(password)

        user.save()  # what is using=self._db?
        return user

    def create_superuser(self, email, phone_number, password=None, **extra_fields):
        """
        Create and save a superuser with the given email, phone number and password.
        """
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)
        extra_fields.setdefault('is_verified', True)  # superusers are automatically verified

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')

        return self.create_user(email, phone_number, password, **extra_fields)


