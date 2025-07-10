from math import degrees

from core_users.models import CustomUser
from django.core.exceptions import ValidationError
from django.db import models



class Degree(models.Model):
    name = models.CharField(max_length=50)
    code = models.CharField(max_length=10)

    def __str__(self):
        return f"{self.name}"


class Program(models.Model):
    """List of Programs offered, like B.Sc, BBA, BCA, MCA, etc."""

    PRE_REQ_STREAM_CHOICES = (
        ("science", "Science"),
        ("arts", "Arts"),
        ("commerce", "Commerce"),
    )

    degree = models.ForeignKey(Degree, on_delete=models.SET_NULL, blank=True, null=True, related_name='available_programs')

    name = models.CharField(max_length=100, unique=True)
    code = models.CharField(max_length=20, unique=True)

    entrance_application_fee = models.DecimalField(decimal_places=2, max_digits=6)

    pre_req_stream = models.CharField(
        choices=PRE_REQ_STREAM_CHOICES, max_length=20, blank=True, null=True
    )

    def __str__(self):
        return f"{self.code}-{self.name}"


class CourseModule(models.Model):
    """Abstract base class for common attributes of different courses"""

    name = models.CharField(max_length=200, unique=True)
    code = models.CharField(max_length=50, unique=True)

    class Meta:
        abstract = True

    def __str__(self):
        return f"{self.code}-{self.name}"


class Minor(CourseModule):
    """Details of Minor offered by the Institute"""

    def __str__(self):
        return f"{self.code}-{self.name}-Minor"


class MultiDisciplinaryCourse(CourseModule):
    """Details of MDC offered by the Institute"""

    def __str__(self):
        return f"{self.code}-{self.name}-MDC"


class ValueAddedCourse(CourseModule):
    """Details of VAC offered by the Institute"""

    def __str__(self):
        return f"{self.code}-{self.name}-VAC"


class AbilityEnhancementCourse(CourseModule):
    """Details of AEC offered by the Institute"""

    def __str__(self):
        return f"{self.code}-{self.name}-AEC"


class AddOnCourse(CourseModule):
    """Details of AOC offered by the Institute"""

    aoc_course_fee = models.DecimalField(decimal_places=2, max_digits=6)

    def __str__(self):
        return f"{self.code}-{self.name}-AOC"


class Major(CourseModule):
    """Details of Major offered by the Institute"""

    STREAM_CHOICES = (
        ("science", "Science"),
        ("arts", "Arts"),
        ("commerce", "Commerce"),
    )

    prereq_stream = models.CharField(
        choices=STREAM_CHOICES, max_length=20, blank=True, null=True
    )

    program = models.ForeignKey(
        Program, on_delete=models.CASCADE, related_name="majors"
    )
    available_minors = models.ManyToManyField(Minor, related_name="minor_in_majors", blank=True)
    available_mdc = models.ManyToManyField(
        MultiDisciplinaryCourse, related_name="mdc_in_majors", blank=True
    )

    entrance_exam_DateTime = models.DateTimeField(blank=True, null=True)

    major_course_fee = models.DecimalField(decimal_places=2, max_digits=6)

    actual_available_seats = models.IntegerField()
    buffer_seats = models.IntegerField()
    total_seats = models.IntegerField(blank=True, null=True)

    def __str__(self):
        return f"{self.code}-{self.name}-Major"

    def save(self, *args, **kwargs):
        """Automatically calculate total seats"""
        self.total_seats = (self.actual_available_seats or 0) + (self.buffer_seats or 0)
        super().save(*args, **kwargs)


class CourseApplication(models.Model):
    """Course Application model for the user, one user might apply for more than one choices"""
    # TODO add logic for multiple application logic as explained by institute

    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)

    degree = models.ForeignKey(Degree, on_delete=models.CASCADE, null=True, blank=True)
    program = models.ForeignKey(Program, on_delete=models.CASCADE, null=True, blank=True)

    major = models.ForeignKey(Major, on_delete=models.CASCADE, null=True, blank=True)
    minor = models.ForeignKey(Minor, on_delete=models.CASCADE, null=True, blank=True)
    mdc = models.ForeignKey(MultiDisciplinaryCourse, on_delete=models.CASCADE, null=True, blank=True)

    vac = models.ForeignKey(ValueAddedCourse, on_delete=models.CASCADE, null=True, blank=True)
    aec = models.ForeignKey(AbilityEnhancementCourse, on_delete=models.CASCADE, null=True, blank=True)
    aoc = models.ForeignKey(AddOnCourse, on_delete=models.CASCADE, null=True, blank=True)

    fee_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    is_fee_paid = models.BooleanField(default=False)

    def __str__(self):
        return f"CourseApplication for {self.user.application.application_id}"









