from pygments.style import Style
from pygments.token import Token, Comment, Keyword, Name, String, \
     Error, Generic, Number, Operator

class CustomStyle(Style):
    styles = {
        Token:                  '',
        Comment:                'italic #A44',
        Keyword:                'bold #005',
        Name:                   '#f00',
        Name.Class:             'bold #0f0',
        Name.Function:          '#0f0',
        String:                 'bg:#eee #111',

        # testing stuff
        Token.Custom.Stuff:     '#0f0',
        Token.String.Template.Meta.Embedded.Line.Variable: '#00f'
    }