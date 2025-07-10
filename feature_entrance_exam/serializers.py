from rest_framework import serializers
from .models import (
    Degree, Program, Major, Minor, MultiDisciplinaryCourse,
    ValueAddedCourse, AbilityEnhancementCourse, AddOnCourse,
    CourseApplication
)
from core_users.models import CustomUser


class DegreeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Degree
        fields = ['id', 'name', 'code']


class ProgramSerializer(serializers.ModelSerializer):

    class Meta:
        model = Program
        fields = ['id', 'name', 'code', 'pre_req_stream', 'entrance_application_fee']


class MinorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Minor
        fields = ['id', 'name', 'code']


class MDCSerializer(serializers.ModelSerializer):
    class Meta:
        model = MultiDisciplinaryCourse
        fields = ['id', 'name', 'code']


class VACSerializer(serializers.ModelSerializer):
    class Meta:
        model = ValueAddedCourse
        fields = ['id', 'name', 'code']


class AECSerializer(serializers.ModelSerializer):
    class Meta:
        model = AbilityEnhancementCourse
        fields = ['id', 'name', 'code']


class AOCSerializer(serializers.ModelSerializer):
    class Meta:
        model = AddOnCourse
        fields = ['id', 'name', 'code', 'aoc_course_fee']


class MajorSerializer(serializers.ModelSerializer):

    class Meta:
        model = Major
        fields = [
            'id', 'name', 'code', 'prereq_stream', 'major_course_fee'
        ]

# Serilazer for CourseApplication
class CourseApplicationDetailSerializer(serializers.ModelSerializer):
    """(OUTPUT) Serializer for showing the full state of a user's course-application"""

    degree = DegreeSerializer(read_only=True)
    program = ProgramSerializer(read_only=True)
    major = MajorSerializer(read_only=True)
    minor = MinorSerializer(read_only=True)
    mdc = MDCSerializer(read_only=True)
    vac = VACSerializer(read_only=True)
    aec = AECSerializer(read_only=True)
    aoc = AOCSerializer(read_only=True)

    class Meta:
        model = CourseApplication
        fields = [
            'id', 'degree', 'program', 'major', 'minor', 'mdc',
            'vac', 'aec', 'aoc', 'fee_amount', 'is_fee_paid'
        ]

class CourseApplicationStateSerializer(serializers.Serializer):
    """(INPUT) Validates the IDs sent in the PUT request body."""
    degree = serializers.PrimaryKeyRelatedField(queryset=Degree.objects.all(), required=False, allow_null=True)
    program = serializers.PrimaryKeyRelatedField(queryset=Program.objects.all(), required=False, allow_null=True)
    major = serializers.PrimaryKeyRelatedField(queryset=Major.objects.all(), required=False, allow_null=True)
    minor = serializers.PrimaryKeyRelatedField(queryset=Minor.objects.all(), required=False, allow_null=True)
    mdc = serializers.PrimaryKeyRelatedField(queryset=MultiDisciplinaryCourse.objects.all(), required=False,
                                             allow_null=True)
    vac = serializers.PrimaryKeyRelatedField(queryset=ValueAddedCourse.objects.all(), required=False, allow_null=True)
    aec = serializers.PrimaryKeyRelatedField(queryset=AbilityEnhancementCourse.objects.all(), required=False,
                                             allow_null=True)
    aoc = serializers.PrimaryKeyRelatedField(queryset=AddOnCourse.objects.all(), required=False, allow_null=True)

