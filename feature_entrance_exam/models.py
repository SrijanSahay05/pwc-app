from math import degrees

from core_users.models import CustomUser
from django.core.exceptions import ValidationError
from django.db import models


class Degree(models.Model):
    """
    Top-level academic degree (e.g., Bachelor's, Master's)
    
    Model Fields:
        - name: Full degree name
        - code: Short degree code
    """
    name = models.CharField(max_length=50)
    code = models.CharField(max_length=10)

    def __str__(self):
        return f"{self.name}"


class Program(models.Model):
    """
    Specific program under a degree (e.g., B.Sc, BBA, MCA)
    
    Model Fields:
        - degree: Foreign key to Degree
        - name: Program name
        - code: Program code
        - entrance_application_fee: Application fee for this program
        - pre_req_stream: Required 12th stream (Science/Commerce/Arts)
    """

    PRE_REQ_STREAM_CHOICES = (
        ("science", "Science"),
        ("arts", "Arts"),
        ("commerce", "Commerce"),
    )

    # Core relationship
    degree = models.ForeignKey(Degree, on_delete=models.SET_NULL, blank=True, null=True, related_name='available_programs')

    # Program details
    name = models.CharField(max_length=100, unique=True)
    code = models.CharField(max_length=20, unique=True)
    entrance_application_fee = models.DecimalField(decimal_places=2, max_digits=6)

    # Eligibility criteria
    pre_req_stream = models.CharField(
        choices=PRE_REQ_STREAM_CHOICES, max_length=20, blank=True, null=True
    )

    def __str__(self):
        return f"{self.code}-{self.name}"


class CourseModule(models.Model):
    """
    Abstract base class for common attributes of different course types
    
    Provides common fields for all course types:
        - name: Course name
        - code: Course code
    """

    name = models.CharField(max_length=200, unique=True)
    code = models.CharField(max_length=50, unique=True)

    class Meta:
        abstract = True

    def __str__(self):
        return f"{self.code}-{self.name}"


class Minor(CourseModule):
    """
    Additional specialization courses offered by the Institute
    
    Inherits from CourseModule with common name and code fields
    """

    def __str__(self):
        return f"{self.code}-{self.name}-Minor"


class MultiDisciplinaryCourse(CourseModule):
    """
    Cross-disciplinary courses offered by the Institute
    
    Inherits from CourseModule with common name and code fields
    """

    def __str__(self):
        return f"{self.code}-{self.name}-MDC"


class ValueAddedCourse(CourseModule):
    """
    Skill enhancement courses offered by the Institute
    
    Inherits from CourseModule with common name and code fields
    """

    def __str__(self):
        return f"{self.code}-{self.name}-VAC"


class AbilityEnhancementCourse(CourseModule):
    """
    General ability courses offered by the Institute
    
    Inherits from CourseModule with common name and code fields
    """

    def __str__(self):
        return f"{self.code}-{self.name}-AEC"


class AddOnCourse(CourseModule):
    """
    Additional paid courses offered by the Institute
    
    Model Fields:
        - Inherits common fields from CourseModule
        - aoc_course_fee: Fee for this additional course
    """

    aoc_course_fee = models.DecimalField(decimal_places=2, max_digits=6)

    def __str__(self):
        return f"{self.code}-{self.name}-AOC"


class Major(CourseModule):
    """
    Specialization under a program (e.g., Computer Science, Physics)
    
    Model Fields:
        - program: Foreign key to Program
        - prereq_stream: Required stream for this major
        - available_minors: Many-to-many with Minor courses
        - available_mdc: Many-to-many with MultiDisciplinaryCourse
        - seat management: actual, buffer, and total seats
        - entrance_exam_DateTime: Exam date and time
        - major_course_fee: Fee for this major
    """

    STREAM_CHOICES = (
        ("science", "Science"),
        ("arts", "Arts"),
        ("commerce", "Commerce"),
    )

    # Eligibility criteria
    prereq_stream = models.CharField(
        choices=STREAM_CHOICES, max_length=20, blank=True, null=True
    )

    # Core relationship
    program = models.ForeignKey(
        Program, on_delete=models.CASCADE, related_name="majors"
    )
    
    # Available course options
    available_minors = models.ManyToManyField(Minor, related_name="minor_in_majors", blank=True)
    available_mdc = models.ManyToManyField(
        MultiDisciplinaryCourse, related_name="mdc_in_majors", blank=True
    )

    # Exam and fee details
    entrance_exam_DateTime = models.DateTimeField(blank=True, null=True)
    major_course_fee = models.DecimalField(decimal_places=2, max_digits=6)

    # Seat management
    actual_available_seats = models.IntegerField()
    buffer_seats = models.IntegerField()
    total_seats = models.IntegerField(blank=True, null=True)

    def __str__(self):
        return f"{self.code}-{self.name}-Major"

    def save(self, *args, **kwargs):
        """
        Override save method to auto-calculate total seats
        
        PHASE 1: Calculate total seats from actual and buffer
        PHASE 2: Call parent save method
        """
        # PHASE 1: Calculate total seats
        self.total_seats = (self.actual_available_seats or 0) + (self.buffer_seats or 0)
        
        # PHASE 2: Call parent save method
        super().save(*args, **kwargs)


class CourseApplication(models.Model):
    """
    Course Application model for tracking user course selections
    
    Model Fields:
        - user: Foreign key to CustomUser
        - Academic hierarchy: degree, program, major
        - Course selections: minor, mdc, vac, aec, aoc
        - Payment tracking: fee_amount, is_fee_paid
    """
    # TODO: add logic for multiple application logic as explained by institute

    # Core relationship
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)

    # Academic hierarchy selections
    degree = models.ForeignKey(Degree, on_delete=models.CASCADE, null=True, blank=True)
    program = models.ForeignKey(Program, on_delete=models.CASCADE, null=True, blank=True)
    major = models.ForeignKey(Major, on_delete=models.CASCADE, null=True, blank=True)
    
    # Course type selections
    minor = models.ForeignKey(Minor, on_delete=models.CASCADE, null=True, blank=True)
    mdc = models.ForeignKey(MultiDisciplinaryCourse, on_delete=models.CASCADE, null=True, blank=True)
    vac = models.ForeignKey(ValueAddedCourse, on_delete=models.CASCADE, null=True, blank=True)
    aec = models.ForeignKey(AbilityEnhancementCourse, on_delete=models.CASCADE, null=True, blank=True)
    aoc = models.ForeignKey(AddOnCourse, on_delete=models.CASCADE, null=True, blank=True)

    # Payment tracking
    fee_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    is_fee_paid = models.BooleanField(default=False)

    def __str__(self):
        return f"CourseApplication for {self.user.application.application_id}"









