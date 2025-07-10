from core_users.authentication_models import CustomUser
from django.db import models
from django.utils import timezone

# TODO: make changes to fix mandatory fields check


class UserApplication(models.Model):
    """
    User Application model for storing personal and family details
    
    Model Fields:
        - Personal details: dob, gender, profile picture
        - Address: current and permanent addresses
        - Family details: father, mother information
        - Certificates: aadhaar, caste, EWS, disability certificates
        - Auto-generated application ID
    """

    GENDER_CHOICES = (('male', 'Male'),
                      ('female', 'Female'))

    # Core relationship
    user = models.OneToOneField(CustomUser, related_name='application', on_delete=models.CASCADE)  # TODO: gracefully handle user account deletion.
    application_id = models.CharField(unique=True, null=True, blank=True)

    # Personal details
    date_of_birth = models.DateField(null=True)
    gender = models.CharField(choices=GENDER_CHOICES, max_length=6, null=True)
    profile_picture = models.ImageField(upload_to='id_pics/', null=True, blank=True)

    # Identity and address
    aadhaar_number = models.CharField(max_length=12, unique=True)
    aadhaar_certificate = models.FileField(upload_to='aadhaar/', null=True, blank=True)
    current_address = models.TextField(null=True)
    permanent_address = models.TextField(null=True)

    # Family details
    father_name = models.CharField(max_length=30, null=True)
    father_number = models.CharField(max_length=10, null=True)
    father_occupation = models.CharField(max_length=100, null=True)

    mother_name = models.CharField(max_length=30, null=True)
    mother_number = models.CharField(max_length=10, null=True)
    mother_occupation = models.CharField(max_length=100, null=True)

    # TODO: similar to mother and father add guardian details here if needed

    # Caste and reservation details
    caste = models.CharField(null=True)  # TODO: define a caste_choices and use that here
    caste_certificate = models.FileField(upload_to='caste_certificates/', null=True, blank=True)

    is_ews = models.BooleanField(default=False)
    ews_certificate = models.FileField(upload_to='ews_certificates/', null=True, blank=True)

    is_disabled = models.BooleanField(default=False)
    disability_certificate = models.FileField(upload_to='disability_certificate/', null=True, blank=True)

    def __str__(self):
        return f"{self.application_id}:{self.user.first_name.capitalize()}"

    # TODO: move to services later on
    def generate_user_application_id(self):
        """
        Generate unique application ID for the user
        
        PHASE 1: Get current year
        PHASE 2: Find last application ID for current year
        PHASE 3: Calculate next sequence number
        PHASE 4: Return formatted application ID
        """
        # PHASE 1: Get current year
        current_year = timezone.now().year
        
        # PHASE 2: Find last application for current year
        last_app = UserApplication.objects.filter(
            application_id__startswith=f'PWC{current_year}'
        ).order_by('-application_id').first()

        # PHASE 3: Calculate next sequence number
        if last_app:
            try:
                next_seq = int(last_app.application_id[8:])
            except ValueError:
                next_seq = 1
        else:
            next_seq = 1
            
        # PHASE 4: Return formatted application ID
        return f'PWC{current_year}{next_seq:05d}'

    def save(self, *args, **kwargs):
        """
        Override save method to auto-generate application ID
        
        PHASE 1: Generate application ID if not exists
        PHASE 2: Call parent save method
        """
        # PHASE 1: Generate application ID if not exists
        self.application_id = self.generate_user_application_id()
        
        # PHASE 2: Call parent save method
        super().save(*args, **kwargs)


class EducationDetailsModel(models.Model):
    """
    Education Details for storing 10th and 12th education information
    
    Model Fields:
        - 10th details: school, board, subject marks, total marks
        - 12th details: school, board, stream, subject marks, total marks
        - Support for appearing students (12th marks optional)
        - Auto-calculated total marks
    """
    
    STREAM_CHOICES = (
        ('science', 'Science'),
        ('commerce', 'Commerce'),
        ('arts', 'Arts')
    )

    # Core relationships
    user = models.OneToOneField(CustomUser, on_delete=models.CASCADE, related_name='education_detail')  # TODO: think a better way to handle user deletion
    user_application = models.OneToOneField(UserApplication, on_delete=models.CASCADE, related_name='education_detail')

    # 10th Standard details
    school_name_10th = models.CharField(max_length=100, null=True)
    school_board_10th = models.CharField(max_length=100, null=True)  # TODO: fetch the list of all school boards in India and give it as a drop down option

    # 10th subject marks (in percentage)
    subject1_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)
    subject2_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)
    subject3_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)
    subject4_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)
    subject5_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)
    subject6_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)

    total_marks_10th = models.PositiveSmallIntegerField(null=True)

    # 12th Standard details
    is_appearing = models.BooleanField(default=True)  # Controls whether 12th marks are required
    school_name_12th = models.CharField(max_length=100, null=True)
    school_board_12th = models.CharField(max_length=100, null=True)  # TODO: fetch the list of all school boards in India and give it as a drop down option

    subject_stream = models.CharField(choices=STREAM_CHOICES, max_length=8)

    # 12th subject marks (in percentage) - optional for appearing students
    subject1_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)
    subject2_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)
    subject3_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)
    subject4_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)
    subject5_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)
    subject6_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)

    total_marks_12th = models.PositiveSmallIntegerField(null=True, blank=True)

    def __str__(self):
        return f"{self.user_application.application_id}:{self.user.first_name.capitalize()}'s Education Profile"