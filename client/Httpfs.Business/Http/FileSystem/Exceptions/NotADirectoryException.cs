using System;
using System.IO;

namespace Httpfsc.Business.Http.FileSystem.Exceptions
{
    public class NotADirectoryException : IOException
    {
        #region Constructors

        public NotADirectoryException()
        {
        }

        public NotADirectoryException(string message)
            : base(message)
        {
        }

        #endregion
    }
}