using System;
using System.IO;

namespace httpfsc.Business.Http
{
    public sealed class Url
    {
        #region Fields

        private readonly string _url;

        #endregion

        #region Constructors

        public Url(string url)
        {
            this._url = url;
        }

        #endregion

        #region Operators

        public static implicit operator string(Url url)
        {
            return url._url;
        }

        public static implicit operator Url(string url)
        {
            return new Url(url);
        }

        #endregion

        #region Methods

        public override string ToString()
        {
            return this._url;
        }

        public Url Combine(Url url)
        {
            return Path.Combine(this, url);
        }

        #endregion
    }
}