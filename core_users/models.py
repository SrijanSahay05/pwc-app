from core_users.authentication_models import CustomUser
from django.db import models
from django.utils import timezone

# TODO make changes to fix mandatory fields check
class UserApplication(models.Model):
    """
    User Application model for the users

    Model Fields:
        - dob
        - gender
        - profile picture
        - aadhaar number
        - aadhaar certificate
        - current add.
        - permanent add.
        - father's detail (name, number, occupation)
        - mother's detail (name, number, occupation)
        - guardian's detail (name, number, occupation)
        - caste
        - caste category
        - is_ews
        - ews_certificates
        - is_pwd
        - pwd_certificates
    """

    GENDER_CHOICES = (('male', 'Male'),
                      ('female', 'Female'))

    user = models.OneToOneField(CustomUser, related_name='application', on_delete=models.CASCADE)  #TODO gracefully handle user account deletion.
    application_id = models.CharField(unique=True, null=True, blank=True)

    date_of_birth = models.DateField(null=True)
    gender = models.CharField(choices=GENDER_CHOICES, max_length=6, null=True)
    profile_picture = models.ImageField(upload_to='id_pics/', null=True, blank=True)

    aadhaar_number = models.CharField(max_length=12, unique=True)
    aadhaar_certificate = models.FileField(upload_to='aadhaar/', null=True, blank=True)

    current_address = models.TextField(null=True)
    permanent_address = models.TextField(null=True)

    father_name = models.CharField(max_length=30, null=True)
    father_number = models.CharField(max_length=10, null=True)
    father_occupation = models.CharField(max_length=100, null=True)

    mother_name = models.CharField(max_length=30, null=True)
    mother_number = models.CharField(max_length=10, null=True)
    mother_occupation = models.CharField(max_length=100, null=True)

    # TODO similar to mother and father add guardian details here if needed

    caste = models.CharField(null=True) #TODO define a caste_choices and use that here
    caste_certificate = models.FileField(upload_to='caste_certificates/', null=True, blank=True)

    is_ews = models.BooleanField(default=False)
    ews_certificate = models.FileField(upload_to='ews_certificates/', null=True, blank=True)

    is_disabled = models.BooleanField(default=False)
    disability_certificate = models.FileField(upload_to='disability_certificate/', null=True, blank=True)

    def __str__(self):
        return f"{self.application_id}:{self.user.first_name.capitalize()}"

    # TODO move to services later on
    def generate_user_application_id(self):
        """Application_ID generation Logic"""

        current_year = timezone.now().year
        last_app = UserApplication.objects.filter(application_id__startswith=f'PWC{current_year}').order_by('-application_id').first()

        if last_app:
            try:
                next_seq = int(last_app.application_id[8:])
            except ValueError:
                next_seq = 1
        else:
            next_seq = 1
        return f'PWC{current_year}{next_seq:05d}'

    def save(self, *args, **kwargs):
        """Saves the UserApplication ID here"""
        self.application_id = self.generate_user_application_id()
        super().save(*args,**kwargs)

class EducationDetailsModel(models.Model):
    """
    Education Details for the Registered User

    Model Fields:
        - user
        - user_application
        - 10th school details (name, board, add.,etc)
        - 10th subject wise marks input (in %age) {6 subjects || 5 mandatory}
        - 10th total marks %age (auto calculated)
        - is_appearing {12th marks field depends on this}
        - 12th school details (name, board, add., etc)
        - 12th stream {later to be used while deciding the major for the applicants}
        - 12th subject wise marks input (in %age) {6 subjects || 5 mandatory}
        - 12th total marks (auto calculated)
    """
    STREAM_CHOICES = (
    ('science', 'Science'),
    ('commerce', 'Commerce'),
    ('arts', 'Arts')
    )

    user = models.OneToOneField(CustomUser, on_delete=models.CASCADE, related_name='education_detail') # TODO think a better way to handle user deletion
    user_application = models.OneToOneField(UserApplication, on_delete=models.CASCADE, related_name='education_detail')

    school_name_10th = models.CharField(max_length=100, null=True)
    school_board_10th = models.CharField(max_length=100, null=True) #TODO fetch the list of all school boards in India and give it as a drop down option

    subject1_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)
    subject2_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)
    subject3_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)
    subject4_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)
    subject5_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)
    subject6_marks_10th = models.PositiveSmallIntegerField(help_text='marks in %', null=True)

    total_marks_10th = models.PositiveSmallIntegerField(null=True)

    is_appearing = models.BooleanField(default=True)

    school_name_12th = models.CharField(max_length=100, null=True)
    school_board_12th = models.CharField(max_length=100, null=True)  # TODO fetch the list of all school boards in India and give it as a drop down option

    subject_stream = models.CharField(choices = STREAM_CHOICES, max_length=8)

    subject1_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)
    subject2_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)
    subject3_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)
    subject4_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)
    subject5_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)
    subject6_marks_12th = models.PositiveSmallIntegerField(help_text='marks in %', null=True, blank=True)

    total_marks_12th = models.PositiveSmallIntegerField(null=True, blank=True)

    def __str__(self):
        return f"{self.user_application.application_id}:{self.user.first_name.capitalize()}'s Education Profile"