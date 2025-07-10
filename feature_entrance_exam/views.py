from django.shortcuts import get_object_or_404
from rest_framework import status, permissions
from rest_framework.response import Response
from feature_entrance_exam.models import CourseApplication, Degree, Program, Major, Minor, ValueAddedCourse, MultiDisciplinaryCourse, AbilityEnhancementCourse, AddOnCourse
from feature_entrance_exam.serializers import (
    CourseApplicationDetailSerializer, CourseApplicationStateSerializer, DegreeSerializer, ProgramSerializer,
    MajorSerializer, MinorSerializer, MDCSerializer, VACSerializer, AECSerializer, AOCSerializer
)
from rest_framework.views import APIView


class CourseApplicationAPIView(APIView):
    """API Views for CourseApplication Model"""
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request):
        # 1. Get or create the single application object for logged-in user
        application, created = CourseApplication.objects.get_or_create(user=request.user)

        # 2. Validate the incoming data from the PUT request
        state_serializer = CourseApplicationStateSerializer(data=request.data)
        state_serializer.is_valid(raise_exception=True)
        validated_data = state_serializer.validated_data

        # 3. Update the application object, clearing dependent fields if necessary.
        if application.program != validated_data.get('program'):
            application.major = None
            application.minor = None
            application.mdc = None
        if application.major != validated_data.get('major'):
            application.minor = None
            application.mdc = None

        #  Update all fields from validated data. Universal courses aren't affected
        #  by the logic above

        application.degree = validated_data.get('degree')
        application.program = validated_data.get('program')
        application.major = validated_data.get('major')
        application.minor = validated_data.get('minor')
        application.mdc = validated_data.get('mdc')
        application.vac = validated_data.get('vac')
        application.aec = validated_data.get('aec')
        application.aoc = validated_data.get('aoc')

        # Check if all required fields are filled before saving
        required_fields = ['degree', 'program', 'major', 'minor', 'mdc', 'vac', 'aec', 'aoc']
        all_fields_filled = all(getattr(application, field) is not None for field in required_fields)
        
        if all_fields_filled:
            # Save the application to database only when all fields are complete
            application.save()

        # 4. Construct the response object.

        # PART A: User's currently saved selection (fully detailed)
        selected_values = CourseApplicationDetailSerializer(application).data

        # PART B: The next available options based on the user's choices
        available_options = {}
        
        if application.major:
            available_options['minors'] = MinorSerializer(application.major.available_minors.all(), many=True).data
            available_options['mdcs'] = MDCSerializer(application.major.available_mdc.all(), many=True).data

        elif application.program:
            available_options['majors'] = MajorSerializer(application.program.majors.all(), many=True).data
        elif application.degree:
            available_options['programs'] = ProgramSerializer(application.degree.available_programs.all(), many=True).data
        else:
            available_options['degrees'] = DegreeSerializer(Degree.objects.all(), many=True).data

        # Add universal courses to available_options
        available_options['vacs'] = VACSerializer(ValueAddedCourse.objects.all(), many=True).data
        available_options['aecs'] = AECSerializer(AbilityEnhancementCourse.objects.all(), many=True).data
        available_options['aocs'] = AOCSerializer(AddOnCourse.objects.all(), many=True).data

        # Remove options for courses that are already selected
        course_field_mapping = {
            'degree': 'degrees',
            'program': 'programs', 
            'major': 'majors',
            'minor': 'minors',
            'mdc': 'mdcs',
            'vac': 'vacs',
            'aec': 'aecs',
            'aoc': 'aocs'
        }

        # Loop through all course fields and remove selected ones from available_options
        for field_name, option_key in course_field_mapping.items():
            if getattr(application, field_name) is not None and option_key in available_options:
                available_options.pop(option_key)

        # 5. creating the context

        context = {
            "selected_values" : selected_values,
            "available_options" : available_options
        }

        return Response(context, status=status.HTTP_200_OK)