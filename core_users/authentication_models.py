from core_users.managers import CustomUserManager
from datetime import timezone
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils import timezone

# Create your models here.


class CustomUser(AbstractUser):
    """
    Custom user authentication model for PWC application
    
    Model Fields:
        - email: Primary identifier (unique)
        - phone: Secondary identifier (unique)
        - first_name, last_name: User's full name
        - username: Disabled (uses email instead)
        - is_admitted: Admission status
        - admission_date: Date of admission
        - created_at, updated_at: Timestamps
        - is_active: Account status
    """

    # Core identification fields
    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=10, unique=True)
    first_name = models.CharField(max_length=30)
    last_name = models.CharField(max_length=30)

    # Disable username field (use email instead)
    username = None

    # Admission tracking
    is_admitted = models.BooleanField(default=False)
    admission_date = models.DateTimeField(null=True, blank=True)

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Account status
    is_active = models.BooleanField(default=True)

    # Custom manager
    objects = CustomUserManager()

    # Authentication configuration
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['phone']

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.first_name} {self.last_name} : {self.email}"


class RegistrationSession(models.Model):
    """
    Registration session for multi-step user registration flow
    
    Model Fields:
        - email, phone: User contact information
        - first_name, last_name: User's name
        - is_email_verified, is_phone_verified: Verification status
        - expires_at: Session expiry timestamp
    """

    # User information
    email = models.EmailField()
    phone = models.CharField(max_length=10)
    first_name = models.CharField(max_length=30)
    last_name = models.CharField(max_length=30)

    # Verification status
    is_email_verified = models.BooleanField(default=False)
    is_phone_verified = models.BooleanField(default=False)

    # Session management
    expires_at = models.DateTimeField()

    def __str__(self):
        return f"Registration Session for {self.email} - {self.phone}"

    def is_expired(self):
        """
        Check if registration session has expired
        
        PHASE 1: Compare current time with expiry time
        PHASE 2: Return expiry status
        """
        # PHASE 1: Check if current time is past expiry
        return timezone.now() > self.expires_at
